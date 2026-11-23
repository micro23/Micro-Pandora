import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "Api.js" as Api

Item {
  id: root

  property bool playing: false
  property bool active: visible
  property bool lyricsBelow: false
  clip: lyricsBelow
  property var barColors: [Commons.Color.accent]
  property color dimColor: Commons.Color.muted
  property int barCount: 56
  property real centerHeight: height
  property real protectedWidth: 0
  property int modeIndex: 0
  readonly property var linearTones: bandTones(false)
  readonly property var modeNames: ["Spectrum", "Mirror", "Orbit", "Off"]
  readonly property string modeName: modeNames[modeIndex]
  readonly property bool visualizing: modeIndex !== 3
  readonly property bool shouldCapture: active && playing && visualizing
  property bool initialized: false
  property string monitor: ""
  property string captureError: ""

  property var levels: blankLevels()
  property var displayLevels: blankLevels()
  property var peakLevels: blankLevels()
  property bool settling: false
  readonly property bool animateLevels: shouldCapture && !Commons.Style.reduceMotion
  readonly property real canvasScale: Math.max(1, width / 1536, height / 864)
  readonly property real stageEnergy: {
    if (!animateLevels) return 0
    if (modeIndex === 2) return orbit.lift
    var sum = 0
    var count = Math.min(10, displayLevels.length)
    for (var i = 0; i < count; i++) sum += displayLevels[i]
    return count ? Math.max(0, (sum / count - 0.06) / 0.94) : 0
  }

  readonly property string runner: Api.helperPath(Qt.resolvedUrl("../helpers/cava-run"))

  function nextMode() {
    selectMode((modeIndex + 1) % modeNames.length)
  }

  function selectMode(index) {
    if (index >= 0 && index < modeNames.length) modeIndex = index
  }

  function bandTones(circular) {
    var colors = []
    for (var i = 0; i < barCount; i++)
      colors.push(playing ? gradientColor(i, circular) : dimColor)
    return colors
  }

  function refreshMonitor() {
    if (shouldCapture && !monitorProc.running) monitorProc.running = true
  }

  function stopCapture() {
    if (!cavaProc.running) return
    cavaProc.stopping = true
    cavaProc.running = false
  }

  function startCapture() {
    if (!shouldCapture || !monitor || captureError || cavaProc.running || cavaProc.stopping) return
    cavaProc.currentMonitor = monitor
    cavaProc.command = [runner, "--source", monitor]
    cavaProc.running = true
  }

  onShouldCaptureChanged: {
    if (!initialized) return
    if (shouldCapture) {
      captureError = ""
      refreshMonitor()
    } else {
      monitor = ""
      stopCapture()
      levels = blankLevels()
    }
  }
  Component.onCompleted: {
    initialized = true
    refreshMonitor()
  }

  function blankLevels() {
    var out = []
    for (var i = 0; i < barCount; i++) out.push(0.06)
    return out
  }

  function parseFrame(line) {
    var parts = String(line || "").replace(/;+$/, "").trim().split(";")
    if (parts.length < barCount) return
    var next = []
    var changed = levels.length !== barCount
    for (var i = 0; i < root.barCount; i++) {
      var raw = Number(parts[i] || 0)
      if (!isFinite(raw)) raw = 0
      var level = Math.max(0.03, Math.pow(Api.clampUnit(raw / 100), 0.70))
      next.push(level)
      changed = changed || level !== levels[i]
    }
    if (changed) levels = next
  }

  function gradientColor(index, circular) {
    if (!barColors.length) return dimColor
    var position = circular ? index / Math.max(1, barCount) * barColors.length
      : index / Math.max(1, barCount - 1) * (barColors.length - 1)
    var start = barColors[Math.floor(position) % barColors.length]
    var end = barColors[Math.ceil(position) % barColors.length]
    var fraction = position % 1
    return Qt.rgba(
      start.r + (end.r - start.r) * fraction,
      start.g + (end.g - start.g) * fraction,
      start.b + (end.b - start.b) * fraction,
      1
    )
  }

  function settleLevels(seconds) {
    var elapsed = Math.max(0.001, Math.min(0.05, seconds))
    var attack = 1 - Math.exp(-elapsed / 0.034)
    var release = 1 - Math.exp(-elapsed / 0.13)
    var next = []
    var peaks = []
    var moving = false
    for (var i = 0; i < barCount; i++) {
      var target = levels[i] || 0.03
      var previous = displayLevels[i] || 0.03
      var value = previous + (target - previous) * (target > previous ? attack : release)
      if (Math.abs(target - value) < 0.004) value = target
      var peak = Math.max(value, target, (peakLevels[i] || value) - elapsed * 0.89)
      next.push(value)
      peaks.push(peak)
      moving = moving || value !== target || peak > value + 0.004
    }
    displayLevels = next
    peakLevels = peaks
    settling = moving
  }

  onLevelsChanged: {
    if (animateLevels) settling = true
    else {
      displayLevels = levels
      peakLevels = levels
    }
  }

  onAnimateLevelsChanged: {
    if (!animateLevels) {
      settling = false
      displayLevels = levels
      peakLevels = levels
    }
  }

  FrameAnimation {
    running: root.animateLevels && root.settling
    onTriggered: root.settleLevels(frameTime)
  }

  function heightLimit(barCenter, barWidth) {
    var sideWidth = (width - protectedWidth) / 2
    if (sideWidth <= 0) return centerHeight

    var gap = Math.abs(barCenter - width / 2) - (protectedWidth + barWidth) / 2
    var shoulder = Math.min(Commons.Style.space(96), sideWidth * 0.6)
    var progress = Math.max(0, Math.min(1, gap / shoulder))
    var eased = progress * progress * (3 - 2 * progress)
    return centerHeight + (height - centerHeight) * eased
  }

  Timer {
    interval: 4000
    repeat: true
    running: root.shouldCapture
    onTriggered: root.refreshMonitor()
  }

  Process {
    id: monitorProc
    command: [root.runner, "--monitor"]
    stdout: StdioCollector { id: monitorOutput; waitForEnd: true }
    onExited: function(code) {
      if (!root.shouldCapture) return
      var next = code === 0 ? monitorOutput.text.trim() || "auto" : "auto"
      if (next !== root.monitor) {
        root.monitor = next
        root.captureError = ""
        root.stopCapture()
      }
      root.startCapture()
    }
  }

  Process {
    id: cavaProc
    property bool stopping: false
    property string currentMonitor: ""
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { if (root.shouldCapture) root.parseFrame(line) }
    }
    stderr: StdioCollector { id: cavaErrors; waitForEnd: true }
    onExited: function(code) {
      var interrupted = stopping
      stopping = false
      if (!root.shouldCapture) return
      if (interrupted || currentMonitor !== root.monitor) {
        Qt.callLater(root.startCapture)
        return
      }
      root.captureError = String(cavaErrors.text || "Cava stopped reading audio.").trim().slice(0, 180)
    }
  }

  Item {
    id: renderLayer

    // Canvas uploads each painted frame. Keep the texture bounded when the
    // player is maximized on a large output.
    width: root.width / root.canvasScale
    height: root.height / root.canvasScale
    scale: root.canvasScale
    transformOrigin: Item.TopLeft
    visible: root.visualizing && !(root.shouldCapture && root.captureError)

    readonly property real centerHeight: root.centerHeight / root.canvasScale
    function heightLimit(x, bandWidth) {
      return root.heightLimit(x * root.canvasScale, bandWidth * root.canvasScale) / root.canvasScale
    }

    SpectrumField {
      anchors.fill: parent
      lyricsBelow: root.lyricsBelow
      levels: visible ? root.displayLevels : []
      peaks: visible ? root.peakLevels : []
      tones: root.linearTones
      heightLimit: renderLayer.heightLimit
      centerHeight: renderLayer.centerHeight
      low: root.linearTones[0] || root.dimColor
      mid: root.linearTones[Math.floor(root.linearTones.length / 2)] || root.dimColor
      high: root.linearTones[root.linearTones.length - 1] || root.dimColor
      playing: root.playing
      showPeaks: root.animateLevels
      opacity: root.modeIndex === 0 ? 1 : 0
      visible: root.modeIndex === 0 || opacity > 0.01

      Behavior on opacity {
        NumberAnimation { duration: Commons.Style.duration(240); easing.type: Easing.OutCubic }
      }
    }

    MirrorRibbon {
      anchors.fill: parent
      lyricsBelow: root.lyricsBelow
      centerHeight: renderLayer.centerHeight
      heightLimit: renderLayer.heightLimit
      opacity: root.modeIndex === 1 ? 1 : 0
      visible: root.modeIndex === 1 || opacity > 0.01
      levels: visible ? root.displayLevels : []
      peakLevels: visible && root.animateLevels ? root.peakLevels : []
      palette: root.playing && root.barColors.length ? root.barColors : [root.dimColor]
      playing: root.playing

      Behavior on opacity {
        NumberAnimation { duration: Commons.Style.duration(220); easing.type: Easing.OutCubic }
      }
    }

    OrbitBands {
      id: orbit
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: renderLayer.centerHeight * 1.74
      opacity: root.modeIndex === 2 ? 1 : 0
      visible: root.modeIndex === 2 || opacity > 0.01
      levels: visible ? root.displayLevels : []
      tones: visible ? root.bandTones(true) : []
      guideColor: root.playing ? root.gradientColor((root.barCount - 1) / 2) : root.dimColor
      playing: root.playing
      motionEnabled: root.active && !Commons.Style.reduceMotion && root.modeIndex === 2

      Behavior on opacity {
        NumberAnimation { duration: Commons.Style.duration(220); easing.type: Easing.OutCubic }
      }
    }
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: Commons.Style.space(20)
    width: Math.min(parent.width, Commons.Style.space(550))
    visible: root.shouldCapture && root.captureError !== ""
    textFormat: Text.PlainText
    text: root.captureError
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    color: root.dimColor
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
  }
}
