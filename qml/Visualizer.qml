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

  property var levels: blankLevels()

  readonly property string runner: Api.helperPath(Qt.resolvedUrl("../helpers/cava-run"))

  function blankLevels() {
    var out = []
    for (var i = 0; i < barCount; i++) out.push(0.06)
    return out
  }

  function parseFrame(line) {
    var parts = String(line || "").replace(/;+$/, "").trim().split(";")
    if (parts.length < 8) return
    var next = []
    for (var i = 0; i < root.barCount; i++) {
      var raw = Number(parts[i] || 0)
      if (!isFinite(raw)) raw = 0
      next.push(Math.max(0.03, Math.min(1, raw / 72)))
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

  Process {
    id: cavaProc
    command: [root.runner]
    running: root.active && root.playing
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.parseFrame(line) }
    }
  }

  onPlayingChanged: if (!playing) levels = blankLevels()

  Row {
    id: row
    anchors.fill: parent
    spacing: Math.max(1, Math.floor(width / root.barCount * 0.22))

    Repeater {
      model: root.barCount
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
          NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
        }
      }
    }
  }
}
