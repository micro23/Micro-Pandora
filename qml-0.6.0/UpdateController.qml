import QtQuick
import QtCore as Core
import Quickshell
import Quickshell.Io
import "Api.js" as Api

Item {
  id: root

  required property string currentVersion
  property alias automaticChecks: preferences.automaticChecks
  property string latestVersion: ""
  property string message: ""
  property bool failed: false
  property string action: ""
  readonly property bool busy: action !== ""
  readonly property bool updateAvailable: isNewer(latestVersion, currentVersion)
  readonly property string helper: Api.helperPath(Qt.resolvedUrl("../helpers/release-update"))

  function isNewer(candidate, installed) {
    var version = /^(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})$/
    if (!version.test(candidate) || !version.test(installed)) return false
    var latest = candidate.split(".").map(Number)
    var current = installed.split(".").map(Number)
    for (var i = 0; i < 3; ++i) {
      if (latest[i] !== current[i]) return latest[i] > current[i]
    }
    return false
  }

  function check() {
    if (busy || !currentVersion) return
    action = "check"
    failed = false
    message = "Checking GitHub for a release…"
    process.exec(["timeout", "25", helper, "check"])
  }

  function install() {
    if (busy || !updateAvailable) return
    action = "install"
    failed = false
    message = "Installing Micro-Pandora " + latestVersion + "…"
    process.exec([helper, "install", latestVersion])
  }

  function checked(version) {
    latestVersion = version
    message = updateAvailable ? "Micro-Pandora " + latestVersion + " is available."
      : "You’re up to date."
    if (!updateAvailable || preferences.lastNotified === latestVersion) return
    preferences.lastNotified = latestVersion
    Quickshell.execDetached(["notify-send", "--app-name=Micro-Pandora",
      "Micro-Pandora update available", "Install version " + latestVersion + " from Micro-Pandora Settings."])
  }

  Core.Settings {
    id: preferences
    location: Qt.resolvedUrl("file://" + Quickshell.stateDir + "/micro-pandora-updates.ini")
    category: "Updates"
    property bool automaticChecks: true
    property string lastNotified: ""
  }

  Timer {
    interval: 5500
    running: root.automaticChecks && root.currentVersion !== ""
    onTriggered: root.check()
  }

  Timer {
    interval: 12 * 60 * 60 * 1000
    running: root.automaticChecks && root.currentVersion !== ""
    repeat: true
    onTriggered: root.check()
  }

  Process {
    id: process
    stdout: StdioCollector { id: output }
    stderr: StdioCollector { id: errors }
    onExited: function(code) {
      var action = root.action
      root.action = ""
      if (code !== 0) {
        root.failed = true
        root.message = errors.text.trim().slice(0, 200) || "Could not finish. Try again."
      } else if (action === "check") {
        root.checked(output.text.trim())
      } else {
        Quickshell.execDetached(["notify-send", "--app-name=Micro-Pandora",
          "Micro-Pandora updated", "Version " + root.latestVersion + " is installed."])
        root.message = "Update installed. Reloading the player…"
        Quickshell.execDetached(["omarchy-shell", "shell", "reloadPlugins"])
      }
    }
  }
}
