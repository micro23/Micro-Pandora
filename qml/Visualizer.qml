import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "Api.js" as Api

Item {
  id: root

  property bool playing: false
  property bool active: visible
  property var barColors: [Commons.Color.accent]
  property color dimColor: Commons.Color.muted
  property bool shadedBars: false
  property int barCount: 56
  property real centerHeight: height
  property real protectedWidth: 0
  property int modeIndex: 0
  readonly property var modeNames: ["Spectrum", "Mirror", "Orbit"]
  readonly property string modeName: modeNames[modeIndex]
  readonly property bool shouldCapture: active && playing
  property bool initialized: false
  property string monitor: ""
  property string captureError: ""

  property var levels: blankLevels()
  property var displayLevels: blankLevels()
  property var peakLevels: blankLevels()
  property bool settling: false
  readonly property bool animateLevels: active && playing && !Commons.Style.reduceMotion

  readonly property string runner: Api.helperPath(Qt.resolvedUrl("../helpers/cava-run"))

  function nextMode() {
    modeIndex = (modeIndex + 1) % modeNames.length
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
      onRead: function(line) { root.parseFrame(line) }
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

  onPlayingChanged: if (!playing) levels = blankLevels()

  Item {
    anchors.fill: parent
    visible: !root.captureError

    Row {
      id: row
      anchors.fill: parent
      opacity: root.modeIndex === 0 ? 1 : 0
      visible: root.modeIndex === 0 || opacity > 0.01
      spacing: Math.max(1, Math.floor(width / root.barCount * 0.22))

      Behavior on opacity {
        NumberAnimation { duration: Commons.Style.duration(220); easing.type: Easing.OutCubic }
      }

      Repeater {
        model: row.visible ? root.barCount : 0
        Item {
          id: band
          required property int index
          readonly property color tone: root.gradientColor(index)
          readonly property real availableHeight: root.playing
            ? root.heightLimit(x + width / 2, width) : root.centerHeight
          width: Math.max(3, (row.width - row.spacing * (root.barCount - 1)) / root.barCount)
          height: row.height

          Rectangle {
            id: spectrumBar
            width: parent.width
            height: Math.max(4, band.availableHeight * (root.displayLevels[band.index] || 0.03))
            anchors.bottom: parent.bottom
            radius: Math.max(1, width / 2)
            color: root.playing ? band.tone : root.dimColor
            gradient: root.playing && root.shadedBars ? barShading : null
            opacity: root.playing ? 0.92 : 0.24

            Gradient {
              id: barShading
              GradientStop { position: 0; color: Qt.lighter(band.tone, 1.27) }
              GradientStop { position: 0.34; color: band.tone }
              GradientStop { position: 1; color: Qt.darker(band.tone, 1.95) }
            }
          }

          Rectangle {
            readonly property real peakHeight: band.availableHeight * (root.peakLevels[band.index] || 0)
            readonly property real gap: peakHeight - spectrumBar.height
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, band.height - peakHeight - height)
            width: Math.max(2, parent.width * 0.73)
            height: Math.max(1, Math.min(3, band.width * 0.18))
            radius: height / 2
            color: Qt.lighter(band.tone, 1.33)
            visible: root.animateLevels && peakHeight > 12 && gap > 5
            opacity: Math.min(0.75, gap / 38)
          }
        }
      }
    }

    MirrorRibbon {
      anchors.fill: parent
      centerHeight: root.centerHeight
      heightLimit: root.heightLimit
      opacity: root.modeIndex === 1 ? 1 : 0
      visible: root.modeIndex === 1 || opacity > 0.01
      levels: visible ? root.displayLevels : []
      low: root.playing ? root.gradientColor(0) : root.dimColor
      mid: root.playing ? root.gradientColor((root.barCount - 1) / 2) : root.dimColor
      high: root.playing ? root.gradientColor(root.barCount - 1) : root.dimColor
      playing: root.playing

      Behavior on opacity {
        NumberAnimation { duration: Commons.Style.duration(220); easing.type: Easing.OutCubic }
      }
    }

    OrbitBands {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: root.centerHeight
      opacity: root.modeIndex === 2 ? 1 : 0
      visible: root.modeIndex === 2 || opacity > 0.01
      levels: visible ? root.displayLevels : []
      tones: {
        if (!visible) return []
        var colors = []
        for (var i = 0; i < root.barCount; i++)
          colors.push(root.playing ? root.gradientColor(i, true) : root.dimColor)
        return colors
      }
      guideColor: root.playing ? root.gradientColor((root.barCount - 1) / 2) : root.dimColor
      playing: root.playing

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
