import QtQuick
import Quickshell
import Quickshell.Io
import "Api.js" as Api

Item {
  id: root

  required property string helper
  readonly property string setupHelper: Api.helperPath(Qt.resolvedUrl("../helpers/setup-deps"))
  property bool settingsOpen: false
  property bool hasStations: false
  property bool checked: false
  property bool loaded: false
  property var missing: []
  property string email: ""
  property bool showBackend: false
  property string message: ""
  property bool failed: false
  property bool connecting: false
  readonly property bool ready: checked && missing.length === 0 && loaded
  readonly property bool busy: credentialWriter.running || connecting
  readonly property bool changingWindow: windowCommand.running

  signal reconnectRequested()

  function refresh() {
    dependencyCheck.running = true
  }

  function installDependencies() {
    Quickshell.execDetached(["xdg-terminal-exec", "--", root.setupHelper, "--install"])
  }

  function report(text, error) {
    root.message = text
    root.failed = error
  }

  function save(email, password) {
    if (!ready || busy || changingWindow) return false
    report("Saving in the desktop keyring…", false)
    credentialWriter.payload = JSON.stringify({email: email, password: password})
    credentialWriter.stdinEnabled = true
    credentialWriter.running = true
    return true
  }

  function connectAccount() {
    if (!ready || connecting || !email) return
    connecting = true
    report("Connecting to Pandora…", false)
    reconnectRequested()
  }

  function reconnectFinished(error) {
    if (error) {
      connecting = false
      report(error, true)
    } else {
      connectionTimeout.restart()
      checkConnection()
    }
  }

  function checkConnection() {
    if (!connectionTimeout.running || !hasStations) return
    connectionTimeout.stop()
    connecting = false
    report("Connected to Pandora.", false)
  }

  function setWindowVisible(show) {
    if (!ready || busy || changingWindow) return
    windowCommand.command = ["timeout", "12", helper, "backend-window", show ? "show" : "hide"]
    windowCommand.running = true
  }

  onSettingsOpenChanged: if (settingsOpen) refresh()
  onHasStationsChanged: checkConnection()

  Component.onCompleted: {
    Quickshell.execDetached([setupHelper, "--launcher"])
    refresh()
  }

  Timer {
    interval: 2500
    repeat: true
    running: root.settingsOpen && root.checked && root.missing.length > 0
    onTriggered: root.refresh()
  }

  Timer {
    id: connectionTimeout
    interval: 35000
    onTriggered: {
      root.connecting = false
      root.report("Pandora hasn’t returned your stations. Check your credentials and connection, then try again.", true)
    }
  }

  Process {
    id: dependencyCheck
    command: ["timeout", "6", root.setupHelper, "--check"]
    stdout: StdioCollector { id: dependencyOutput; waitForEnd: true }
    onExited: function(code) {
      var info = Api.parseStatus(dependencyOutput.text)
      if (code !== 0 || !info || !Array.isArray(info.missing)) {
        root.report("Could not check the installed packages.", true)
        return
      }
      root.missing = info.missing
      root.checked = true
      if (root.missing.length > 0) root.loaded = false
      else if (!root.busy && !root.changingWindow) accountRead.running = true
    }
  }

  Process {
    id: accountRead
    command: ["timeout", "6", root.helper, "account-status"]
    stdout: StdioCollector { id: accountOutput; waitForEnd: true }
    onExited: function(code) {
      var info = Api.parseStatus(accountOutput.text)
      if (code !== 0 || !info || !info.pithosInstalled) {
        root.report("Pithos could not load its account settings. Check setup and try again.", true)
        return
      }
      root.email = String(info.email || "")
      root.showBackend = !!info.showBackend
      root.loaded = true
    }
  }

  Process {
    id: credentialWriter
    property string payload: ""
    stdinEnabled: true
    command: ["timeout", "120", root.helper, "account-save"]
    stdout: StdioCollector { id: credentialOutput; waitForEnd: true }
    stderr: StdioCollector { id: credentialError; waitForEnd: true }
    onStarted: {
      write(payload)
      payload = ""
      stdinEnabled = false
    }
    onExited: function(code) {
      payload = ""
      var info = Api.parseStatus(credentialOutput.text)
      if (code !== 0 || !info || !info.saved) {
        root.report(String(credentialError.text || "Sign-in could not be saved.").trim(), true)
        return
      }
      root.email = String(info.email || "")
      root.connectAccount()
    }
  }

  Process {
    id: windowCommand
    stdout: StdioCollector { id: windowOutput; waitForEnd: true }
    onExited: function(code) {
      var result = Api.parseStatus(windowOutput.text)
      if (code === 0 && result && typeof result.showBackend === "boolean") {
        root.showBackend = result.showBackend
      } else {
        root.report("Could not change the backend window. Try again.", true)
      }
    }
  }
}
