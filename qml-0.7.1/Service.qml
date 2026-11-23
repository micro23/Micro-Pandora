import QtQuick
import QtCore as Core
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "Api.js" as Api

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var settings: ({})

  property var status: ({})
  property string commandError: ""
  property string statusError: ""
  readonly property string lastError: commandError || statusError || pinsError
  property var visibleSurfaces: []
  readonly property bool uiVisible: visibleSurfaces.length > 0
  property var playerSurfaces: []
  property var pendingActions: []
  property var stationRows: []
  property string stationSnapshot: "[]"
  property var paletteColors: ({})
  property string paletteSnapshot: "{}"
  property bool daemonStartAttempted: false
  property bool accountRestarting: false
  readonly property alias account: accountController
  readonly property alias updater: updateController

  UpdateController {
    id: updateController
    currentVersion: root.manifest ? String(root.manifest.version || "") : ""
  }
  property bool wanted: false
  property string displayMode: "full" // "full" or "mini"
  property alias stationSidebarCollapsed: viewPreferences.sidebarCollapsed
  property alias visualizerMode: viewPreferences.visualizerMode
  property alias lyricsOn: viewPreferences.lyricsOn

  Core.Settings {
    id: viewPreferences
    location: Qt.resolvedUrl("file://" + Quickshell.stateDir + "/micro-pandora-view.ini")
    category: "Player"
    property bool sidebarCollapsed: false
    property int visualizerMode: 0
    property bool lyricsOn: false
  }

  property string preferredScreenName: ""
  property var pinnedRaw: []
  // Pins are saved only after the pins file was read cleanly or found
  // missing, so a file that fails to load is never overwritten.
  property string pinsState: "loading" // "loading", "ok" or "unreadable"
  readonly property string pinsError: pinsState === "unreadable"
    ? "Pins are not being saved: ~/.config/omarchy/omapandora-pins.json could not be read. Fix or move that file."
    : ""

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.micro23.micro-pandora"
  readonly property string helper: Api.helperPath(Qt.resolvedUrl("../helpers/pithosctl"))
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var pithosPlayer: findPithosPlayer()
  readonly property bool connected: !!(status && status.connected)
  onConnectedChanged: {
    if (connected) {
      launchDeadline.stop()
      applyBackendVisibility()
    }
  }
  readonly property bool playing: pithosPlayer ? pithosPlayer.isPlaying : status.status === "Playing"
  readonly property bool hasMedia: connected && (title !== "" || artist !== "")
  function cleanTrackTitle(raw) {
    if (!raw) return ""
    return String(raw).replace(/\s*[\(\[\{]\s*explicit(\s+version|\s+content)?\s*[\)\]\}]\s*/gi, " ").trim()
  }
  readonly property string title: cleanTrackTitle(status.title || (pithosPlayer ? pithosPlayer.trackTitle : "") || "")
  readonly property string artist: String(status.artist || (pithosPlayer ? pithosPlayer.trackArtist : "") || "")
  readonly property string album: cleanTrackTitle(status.album || (pithosPlayer ? pithosPlayer.trackAlbum : "") || "")
  readonly property string artUrl: String(status.artUrl || (pithosPlayer ? pithosPlayer.trackArtUrl : "") || "")
  readonly property string backdropUrl: String(status.backdropUrl || "")
  readonly property var artPalette: paletteColors
  readonly property string stationName: String(status.stationName || "")
  readonly property string stationPath: String(status.stationPath || "")
  readonly property var stations: stationRows
  readonly property bool loved: !!status.loved
  readonly property real volume: Api.clampUnit(pithosPlayer && pithosPlayer.volumeSupported
    ? pithosPlayer.volume : status.volume)
  readonly property bool volumeSupported: pithosPlayer ? pithosPlayer.volumeSupported : connected
  readonly property real lengthSeconds: Number(status.lengthMs || 0) / 1000
  readonly property real positionSeconds: {
    var value = pithosPlayer && pithosPlayer.positionSupported
      ? pithosPlayer.position : Number(status.positionMs || 0) / 1000
    return Math.max(0, lengthSeconds > 0 ? Math.min(value, lengthSeconds) : value)
  }

  // ── Synced lyrics from lrclib.net ────────────
  readonly property string lyricsHelper: Api.helperPath(Qt.resolvedUrl("../helpers/lyrics"))
  property var lyricLines: []
  property string lyricState: "none"   // "loading", "ready" or "none"
  property string lyricsFetchedKey: ""
  readonly property string lyricsKey: uiVisible && displayMode === "full" && connected && title !== ""
    ? artist + "\u0001" + title : ""
  onLyricsKeyChanged: lyricsDebounce.restart()

  Timer {
    id: lyricsDebounce
    interval: 400
    onTriggered: {
      if (!root.lyricsKey || root.lyricsKey === root.lyricsFetchedKey) return
      root.lyricsFetchedKey = root.lyricsKey
      root.lyricLines = []
      root.lyricState = "loading"
      lyricsProc.running = false
      var len = root.lengthSeconds > 0 && root.lengthSeconds < 36000 ? Math.round(root.lengthSeconds) : 0
      lyricsProc.command = ["timeout", "25", root.lyricsHelper, root.artist, root.title, root.album, String(len)]
      lyricsProc.running = true
    }
  }

  readonly property bool canGoNext: pithosPlayer ? pithosPlayer.canGoNext : !!status.canGoNext
  readonly property bool launching: launchDeadline.running
  readonly property bool canGoPrevious: false
  readonly property bool showTrackTitle: Api.settingOn(setting("showTrackTitle", "On"), "On")
  readonly property bool showArtistName: Api.settingOn(setting("showArtistName", "Off"), "Off")
  readonly property bool showPausedTrack: Api.settingOn(setting("showPausedTrack", "On"), "On")
  readonly property bool scrollBarText: Api.settingOn(setting("scrollBarText", "Off"), "Off")
  readonly property real maxBarTextWidth: {
    var value = Number(setting("maxBarTextWidth", "240"))
    if (!isFinite(value)) return 240
    if (value <= 0) return 0
    return Math.max(160, Math.min(560, value))
  }
  readonly property bool fixedBarWidth: false
  readonly property var pinnedStations: {
    var saved = Api.parsePinnedStations(pinnedRaw)
    var live = stations
    var out = []
    for (var i = 0; i < saved.length; i++) {
      var item = saved[i] || {}
      var path = Api.stationPath(item)
      if (!path) continue
      var name = String(item.name || "")
      var id = String(item.id || "")
      for (var j = 0; j < live.length; j++) {
        if (String(live[j].path) === path) {
          name = live[j].name || name
          id = live[j].id || id
          break
        }
      }
      out.push({ path: path, name: name || "Station", id: id })
    }
    return out
  }
  readonly property var unpinnedStations: {
    var all = stations
    var out = []
    for (var i = 0; i < all.length; i++)
      if (!isPinned(all[i].path)) out.push(all[i])
    return out
  }

  function setting(key, fallback) {
    if (settings && settings[key] !== undefined && settings[key] !== null)
      return settings[key]
    return fallback
  }

  function applySettings(next) {
    if (next && typeof next === "object") settings = next
  }

  function findPithosPlayer() {
    for (var i = 0; i < players.length; i++) {
      var player = players[i]
      var dbus = String(player && player.dbusName || "").toLowerCase()
      var desktop = String(player && player.desktopEntry || "").toLowerCase()
      var identity = String(player && player.identity || "").toLowerCase()
      if (dbus.indexOf("pithos") !== -1 || desktop.indexOf("pithos") !== -1
          || identity.indexOf("pithos") !== -1)
        return player
    }
    return null
  }

  function setUiVisible(surface, visible) {
    var shown = visibleSurfaces.indexOf(surface) !== -1
    if (shown === visible) return
    var first = !uiVisible
    visibleSurfaces = visible ? visibleSurfaces.concat([surface])
      : visibleSurfaces.filter(function(item) { return item !== surface })
    if (visible && first) {
      wanted = true
      daemonStartAttempted = false
      refresh()
      ensureDaemon()
    }
  }

  function registerPlayerSurface(surface) {
    if (!surface) return
    if (playerSurfaces.indexOf(surface) === -1)
      playerSurfaces = playerSurfaces.concat([surface])
  }

  function unregisterPlayerSurface(surface) {
    setUiVisible(surface, false)
    playerSurfaces = playerSurfaces.filter(function(item) { return item !== surface })
  }

  // Every helper run gets a time limit so a stuck D-Bus call can't stall the shell.
  function helperCommand(seconds, args) {
    return ["timeout", "-k", "5", String(seconds), helper].concat(args)
  }

  function runHelper(args) {
    var queue = pendingActions.slice()
    if (args[0] === "volume" && queue.length && queue[queue.length - 1][0] === "volume")
      queue[queue.length - 1] = args
    else queue.push(args)
    pendingActions = queue
    startHelper()
  }

  function startHelper() {
    if (helperProc.running || !pendingActions.length) return
    var action = pendingActions[0]
    pendingActions = pendingActions.slice(1)
    helperProc.action = action[0]
    helperProc.command = helperCommand(action[0] === "reconnect" ? 24 : 12, action)
    helperProc.running = true
  }

  function reportCommandError(message) {
    commandError = String(message || "Pithos command failed.").trim()
    errorTimeout.restart()
  }

  function applyStatus(parsed) {
    var incomingStations = Array.isArray(parsed.stations) ? parsed.stations : []
    var incomingPalette = parsed.artPalette || ({})
    var stationKey = JSON.stringify(incomingStations)
    var paletteKey = JSON.stringify(incomingPalette)
    if (stationKey !== stationSnapshot) {
      stationSnapshot = stationKey
      stationRows = incomingStations
    }
    if (paletteKey !== paletteSnapshot) {
      paletteSnapshot = paletteKey
      paletteColors = incomingPalette
    }
    status = parsed
  }

  function refresh() {
    if ((!account.ready && !pithosPlayer) || accountRestarting) return
    statusProc.command = helperCommand(15, ["status"])
    statusProc.running = true
  }

  function togglePlayback() {
    if (pithosPlayer && pithosPlayer.canTogglePlaying) pithosPlayer.togglePlaying()
    else runHelper(["playpause"])
    Qt.callLater(refresh)
  }

  function next() {
    if (pithosPlayer && pithosPlayer.canGoNext) pithosPlayer.next()
    else runHelper(["next"])
    Qt.callLater(refresh)
  }

  function rate(action) {
    if (status.trackId) runHelper([action, String(status.trackId)])
  }

  function love() { rate("love") }
  function unrate() { rate("unrate") }
  function toggleLove() { loved ? unrate() : love() }
  function ban() { rate("ban") }
  function tired() { rate("tired") }

  function setVolume(value) {
    var target = Api.clampUnit(value)
    if (pithosPlayer && pithosPlayer.volumeSupported) pithosPlayer.volume = target
    else if (connected) runHelper(["volume", String(target)])
  }

  function adjustVolume(delta) {
    setVolume(volume + delta)
  }

  function activateStation(path) {
    if (!path) return
    runHelper(["station", String(path)])
    Qt.callLater(refresh)
  }

  function isPinned(path) {
    var list = pinnedStations
    var key = String(path || "")
    for (var i = 0; i < list.length; i++)
      if (String(list[i].path) === key) return true
    return false
  }

  function togglePin(station) {
    if (!station) return
    if (pinsState !== "ok") {
      return
    }
    var path = Api.stationPath(station)
    if (!path) return
    var saved = Api.parsePinnedStations(pinnedRaw)
    var next = []
    var found = false
    for (var i = 0; i < saved.length; i++) {
      var item = saved[i] || {}
      var itemPath = Api.stationPath(item)
      if (itemPath === path) {
        found = true
        continue
      }
      if (itemPath)
        next.push({
          path: itemPath,
          name: String(item.name || ""),
          id: String(item.id || "")
        })
    }
    if (!found)
      next.push({
        path: path,
        name: String(station.name || ""),
        id: String(station.id || "")
      })
    pinnedRaw = next
    pinSaver.input = JSON.stringify(next)
    if (!pinSaver.running) pinSaver.running = true
  }

  function launchPithos() {
    if (launching || !account.ready || !account.email || account.busy) return
    commandError = ""
    daemonStartAttempted = true
    runHelper(["launch"])
    launchDeadline.restart()
  }

  function ensureDaemon() {
    if (!wanted) return
    if (connected) return
    launchPithos()
  }

  function reconnectAccount() {
    accountRestarting = true
    daemonStartAttempted = true
    commandError = ""
    applyStatus({})
    runHelper(["reconnect"])
  }

  function applyBackendVisibility() {
    if (account.ready && !account.showBackend && !account.changingWindow)
      runHelper(["hide"])
  }

  function stopAndQuit() {
    wanted = false
    daemonStartAttempted = true
    launchDeadline.stop()
    if (pithosPlayer) {
      if (pithosPlayer.canPause) pithosPlayer.pause()
      else if (pithosPlayer.canTogglePlaying && pithosPlayer.isPlaying)
        pithosPlayer.togglePlaying()
    }
    runHelper(["quit"])
  }

  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  function rememberScreen(screenName) {
    var name = String(screenName || "")
    if (name) preferredScreenName = name
    if (!preferredScreenName) preferredScreenName = focusedScreenName()
    return preferredScreenName
  }

  function screenByName(name) {
    var want = String(name || "")
    if (!want) return null
    var screens = Quickshell.screens
    if (!screens) return null
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && String(screens[i].name) === want) return screens[i]
    }
    return null
  }

  function miniSurface(screenName) {
    var fallback = null
    for (var i = 0; i < playerSurfaces.length; i++) {
      var surface = playerSurfaces[i]
      if (!surface || !surface.miniPlayerEnabled) continue
      if (surface.thisScreenName() === screenName) return surface
      if (!fallback) fallback = surface
    }
    return fallback
  }

  function enterMini(screenName) {
    var surface = miniSurface(screenName)
    if (!surface) return false
    rememberScreen(surface.thisScreenName())
    displayMode = "mini"
    surface.openMiniPopup()
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    return true
  }

  function openFullPlayer(screenName, page) {
    if (!shell) return
    rememberScreen(screenName || focusedScreenName())
    for (var i = 0; i < playerSurfaces.length; i++) {
      var surface = playerSurfaces[i]
      if (surface && surface.opened) surface.close()
    }
    displayMode = "full"
    var payload = JSON.stringify({page: page || ""})
    if (typeof shell.summon === "function") shell.summon(pluginId, payload)
    else if (typeof shell.toggle === "function") shell.toggle(pluginId, payload)
  }

  // Hyprland window dispatch helpers for tile/float and screen pinning.
  readonly property string windowMatch: "title:^(Micro-Pandora)$"
  function hyprWindow(call, args) {
    return "dispatch hl.dsp.window." + call + "({ " + (args ? args + ", " : "")
      + "window = \"" + windowMatch + "\" })"
  }
  function layoutBatch() {
    if (windowTiled) return [hyprWindow("float", "action = \"unset\"")]
    return [
      hyprWindow("float", "action = \"set\""),
      hyprWindow("resize", "x = 1440, y = 900, relative = false"),
      hyprWindow("center", "")
    ]
  }
  function runHypr(steps) {
    pinMonProc.command = ["timeout", "5", "hyprctl", "--batch", steps.join("; ")]
    pinMonProc.running = true
  }

  // Tiled or floating full player, remembered in its own small file.
  property bool windowTiled: false
  function setWindowTiled(on) {
    windowTiled = !!on
    windowFile.setText(JSON.stringify({ tiled: windowTiled }) + "\n")
    runHypr(layoutBatch())
  }

  function pinWindowToPreferredScreen() {
    var name = String(preferredScreenName || "")
    // Monitor names go into a hyprctl batch string; allow only plain names.
    if (!name || name === focusedScreenName() || !/^[A-Za-z0-9_.-]+$/.test(name)) return
    var steps = [hyprWindow("move", "monitor = \"" + name + "\"")]
    runHypr(steps.concat(windowTiled ? layoutBatch() : [hyprWindow("center", "")]))
  }

  IpcHandler {
    target: root.pluginId + ".player"
    function togglePlayer(): string {
      if (!root.shell) return "unavailable"
      if (typeof root.shell.toggle === "function") {
        root.shell.toggle(root.pluginId, "{}")
        return "ok"
      }
      return "unavailable"
    }
    function toggleMiniPlayer(): string {
      var surface = root.miniSurface(root.focusedScreenName())
      if (!surface) return "unavailable"
      if (surface.opened) surface.close()
      else root.enterMini(surface.thisScreenName())
      return "ok"
    }
    function toggleFullPlayer(): string {
      root.openFullPlayer()
      return "ok"
    }
    function openFromLauncher(): string {
      root.openFullPlayer()
      return "ok"
    }
    function setVisualizer(mode: int): string { root.visualizerMode = mode; return "ok" }
    function toggleLyrics(): string { root.lyricsOn = !root.lyricsOn; return "ok" }
    function openSettings(): string {
      root.openFullPlayer("", "setup")
      return "ok"
    }
    function playPause(): string { root.togglePlayback(); return "ok" }
    function next(): string { root.next(); return "ok" }
    function love(): string { root.toggleLove(); return "ok" }
  }

  Process {
    id: statusProc
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    stderr: StdioCollector { id: statusErr; waitForEnd: true }
    onExited: function(code) {
      if (root.accountRestarting) return
      var parsed = Api.parseStatus(statusOut.text)
      if (parsed && code === 0) {
        root.statusError = ""
        root.applyStatus(parsed)
        if (!parsed.connected && root.wanted && !root.daemonStartAttempted) {
          root.ensureDaemon()
        }
      } else {
        root.statusError = String(statusErr.text || "Could not read Pithos.").trim()
      }
    }
  }

  Process {
    id: helperProc
    property string action: ""
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: helperErr; waitForEnd: true }
    onExited: function(code) {
      if (action === "reconnect") {
        root.accountRestarting = false
        accountController.reconnectFinished(code === 0 ? ""
          : String(helperErr.text || "Could not reconnect Pandora.").trim())
      }
      if ((action === "launch" || action === "open") && (code !== 0 || root.connected))
        launchDeadline.stop()
      if (code !== 0) root.reportCommandError(helperErr.text)
      root.refresh()
      Qt.callLater(root.startHelper)
    }
  }

  Process {
    id: pinMonProc
  }

  Process {
    id: lyricsProc
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        var rows = String(text).split("\n")
        for (var i = 0; i < rows.length; i++) {
          var r = rows[i].match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/)
          if (r) out.push({ time: parseInt(r[1]) * 60 + parseFloat(r[2]), text: r[3].trim() })
        }
        root.lyricLines = out
        root.lyricState = out.length ? "ready" : "none"
      }
    }
  }

  AccountController {
    id: accountController
    helper: root.helper
    hasStations: root.connected && root.stations.length > 0
    onReconnectRequested: root.reconnectAccount()
    onReadyChanged: {
      if (!ready) return
      root.applyBackendVisibility()
      root.refresh()
      root.ensureDaemon()
    }
  }

  Timer {
    id: poll
    interval: root.launching ? 700 : root.uiVisible ? 1200 : 4000
    repeat: true
    running: root.uiVisible || root.connected || !!root.pithosPlayer || root.launching
    onTriggered: root.refresh()
  }

  Timer {
    id: launchDeadline
    interval: 15000
    onTriggered: {
      root.refresh()
      if (!root.connected) root.reportCommandError("Pandora has not connected yet. Check Settings to try again.")
    }
  }

  Timer {
    id: errorTimeout
    interval: 8000
    onTriggered: root.commandError = ""
  }

  Timer {
    interval: 125
    repeat: true
    running: root.uiVisible && root.playing && !!root.pithosPlayer && root.pithosPlayer.positionSupported
    onTriggered: root.pithosPlayer.positionChanged()
  }

  Connections {
    target: root.pithosPlayer
    function onPostTrackChanged() { root.refresh() }
    function onPlaybackStateChanged() { root.refresh() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "openwindow" || !root.account.ready || root.account.showBackend ||
          root.account.changingWindow) return
      var windowClass = String(event.data || "").split(",")[2]
      if (/^(pithos|io\.github\.pithos)$/i.test(windowClass || "")) hideNewWindow.restart()
    }
  }

  Timer {
    id: hideNewWindow
    interval: 100
    onTriggered: root.applyBackendVisibility()
  }

  // Pins are written by the helper as a private (0600) file, sent on stdin.
  Process {
    id: pinSaver
    property string input: ""
    property string written: ""
    command: root.helperCommand(10, ["pins-save"])
    stdinEnabled: true
    stderr: StdioCollector { id: pinSaverErr; waitForEnd: true }
    onStarted: {
      written = input
      write(input)
      stdinEnabled = false
    }
    onExited: function(code) {
      stdinEnabled = true
      if (code !== 0) {
        root.reportCommandError(pinSaverErr.text || "Could not save pins.")
        return
      }
      // Pinned again while this save was running: save the newest list too.
      if (input !== written) running = true
    }
  }

  FileView {
    id: pinFile
    path: Quickshell.env("HOME") + "/.config/omarchy/omapandora-pins.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      if (pinSaver.running && root.pinsState === "ok") return
      var saved = Api.readPinnedStations(text())
      root.pinnedRaw = saved || []
      root.pinsState = saved ? "ok" : "unreadable"
    }
    onLoadFailed: function(error) {
      root.pinnedRaw = []
      root.pinsState = error === FileViewError.FileNotFound ? "ok" : "unreadable"
    }
  }

  Component.onCompleted: refresh()
  onPithosPlayerChanged: refresh()

  FileView {
    id: windowFile
    path: Quickshell.env("HOME") + "/.config/omarchy/micro-pandora-window.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try { root.windowTiled = JSON.parse(text()).tiled === true } catch (e) { root.windowTiled = false }
    }
  }
}
