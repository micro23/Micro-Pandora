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

  readonly property string runner: Api.helperPath(Qt.resolvedUrl("../helpers/cava-run"))

  function nextMode() {
    modeIndex = (modeIndex + 1) % modeNames.length
    if (!Commons.Style.reduceMotion) revealMode.restart()
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
    for (var i = 0; i < root.barCount; i++) {
      var raw = Number(parts[i] || 0)
      if (!isFinite(raw)) raw = 0
      next.push(Math.max(0.03, Math.pow(Api.clampUnit(raw / 100), 0.70)))
    }
    levels = next
  }

  function gradientColor(index) {
    var position = index / Math.max(1, barCount - 1) * (barColors.length - 1)
    var start = barColors[Math.floor(position)]
    var end = barColors[Math.ceil(position)]
    var fraction = position % 1
    return Qt.rgba(
      start.r + (end.r - start.r) * fraction,
      start.g + (end.g - start.g) * fraction,
      start.b + (end.b - start.b) * fraction,
      1
    )
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

  NumberAnimation {
    id: revealMode
    target: modeLayer
    property: "opacity"
    from: 0.48
    to: 1
    duration: Commons.Style.duration(180)
    easing.type: Easing.OutCubic
  }

  Item {
    id: modeLayer
    anchors.fill: parent
    visible: !root.captureError

    Row {
      id: row
      anchors.fill: parent
      visible: root.modeIndex === 0
      spacing: Math.max(1, Math.floor(width / root.barCount * 0.22))

      Repeater {
        model: row.visible ? root.barCount : 0
        Rectangle {
          id: spectrumBar
          required property int index
          readonly property color tone: root.gradientColor(index)
          readonly property real availableHeight: root.playing
            ? root.heightLimit(x + width / 2, width) : root.centerHeight
          width: Math.max(3, (row.width - row.spacing * (root.barCount - 1)) / root.barCount)
          height: Math.max(6, availableHeight * (root.levels[index] || 0.03))
          anchors.bottom: parent.bottom
          radius: Math.max(1, width / 2)
          color: root.playing ? tone : root.dimColor
          gradient: root.playing && root.shadedBars ? barShading : null
          opacity: root.playing ? 0.95 : 0.28

          Gradient {
            id: barShading
            GradientStop { position: 0; color: Qt.lighter(spectrumBar.tone, 1.16) }
            GradientStop { position: 0.24; color: spectrumBar.tone }
            GradientStop { position: 1; color: Qt.darker(spectrumBar.tone, 1.66) }
          }

          Behavior on height {
            NumberAnimation { duration: Commons.Style.duration(70); easing.type: Easing.OutQuad }
          }
        }
      }
    }

    Item {
      id: mirror
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: root.centerHeight
      visible: root.modeIndex === 1

      Rectangle {
        width: parent.width
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        color: root.dimColor
        opacity: 0.24
      }

      Repeater {
        model: mirror.visible ? root.barCount : 0
        Rectangle {
          id: mirrorBar
          required property int index
          readonly property color tone: root.playing ? root.gradientColor(index) : root.dimColor
          width: Math.max(2, mirror.width / root.barCount * 0.62)
          height: Math.max(width / 2, mirror.height * 0.88 * (root.levels[index] || 0.03))
          x: (index + 0.5) * mirror.width / root.barCount - width / 2
          y: (mirror.height - height) / 2
          radius: width / 2
          opacity: root.playing ? 0.92 : 0.34
          gradient: Gradient {
            GradientStop { position: 0; color: mirrorBar.tone }
            GradientStop { position: 0.5; color: Qt.lighter(mirrorBar.tone, 1.35) }
            GradientStop { position: 1; color: mirrorBar.tone }
          }
          Behavior on height {
            NumberAnimation { duration: Commons.Style.duration(70); easing.type: Easing.OutQuad }
          }
        }
      }
    }

    Item {
      id: orbit
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: root.centerHeight
      visible: root.modeIndex === 2
      readonly property real radiusX: Math.min(width * 0.37, height * 1.35)
      readonly property real radiusY: height * 0.27

      Repeater {
        model: orbit.visible ? root.barCount : 0
        Rectangle {
          required property int index
          readonly property real angle: index / root.barCount * 2 * Math.PI - Math.PI / 2
          width: Math.max(3, Math.min(Commons.Style.space(8), orbit.height * 0.045))
          height: Math.max(width, orbit.height * 0.20 * (root.levels[index] || 0.03) + width)
          x: orbit.width / 2 + Math.cos(angle) * orbit.radiusX - width / 2
          y: orbit.height / 2 + Math.sin(angle) * orbit.radiusY - height
          rotation: (angle + Math.PI / 2) * 180 / Math.PI
          transformOrigin: Item.Bottom
          radius: width / 2
          color: root.playing ? root.gradientColor(index) : root.dimColor
          opacity: root.playing ? 0.95 : 0.34
          Behavior on height {
            NumberAnimation { duration: Commons.Style.duration(70); easing.type: Easing.OutQuad }
          }
        }
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
