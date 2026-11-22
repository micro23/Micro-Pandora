import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons

Item {
  id: root

  required property var levels
  required property var peaks
  required property var tones
  required property var heightLimit
  required property real centerHeight
  required property color low
  required property color mid
  required property color high
  required property bool playing
  required property bool showPeaks

  readonly property int bands: Math.min(levels.length, tones.length)
  readonly property real floorY: height - Math.min(height * 0.18, Commons.Style.space(54))
  readonly property real pitch: width / Math.max(1, bands)
  readonly property var headroom: {
    var limits = []
    for (var i = 0; i < bands; i++) {
      var x = (i + 0.5) * pitch
      limits.push(playing ? Math.max(0, Math.min(floorY - 9, heightLimit(x, pitch) * 0.83))
        : centerHeight * 0.23)
    }
    return limits
  }
  readonly property var envelope: {
    var points = []
    for (var i = 0; i < bands; i++) {
      var average = (levels[Math.max(0, i - 1)] + 2 * levels[i] + levels[Math.min(bands - 1, i + 1)]) / 4
      points.push(floorY - Math.max(2, (headroom[i] || 0) * average * 0.88))
    }
    return points
  }

  function trace(first, last) {
    var samples = envelope
    var count = samples.length
    last = Math.min(last, count - 1)
    if (count < 2 || last < first) return ""
    var x = pitch * first
    var y = first > 0 ? (samples[first - 1] + samples[first]) / 2 : samples[0]
    var points = ["M", x, y.toFixed(1)]
    for (var i = first; i <= last; i++) {
      var nextY = i < count - 1 ? (samples[i] + samples[i + 1]) / 2 : samples[i]
      points.push("Q", (pitch * (i + 0.5)).toFixed(1), samples[i].toFixed(1),
        (pitch * (i + 1)).toFixed(1), nextY.toFixed(1))
    }
    return points.join(" ")
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    visible: root.bands > 1

    ShapePath {
      strokeWidth: -1
      fillGradient: LinearGradient {
        x2: root.width
        GradientStop { position: 0; color: Commons.Util.alpha(root.low, 0) }
        GradientStop { position: 0.12; color: Commons.Util.alpha(root.low, root.playing ? 0.15 : 0.07) }
        GradientStop { position: 0.50; color: Commons.Util.alpha(root.mid, root.playing ? 0.11 : 0.06) }
        GradientStop { position: 0.88; color: Commons.Util.alpha(root.high, root.playing ? 0.15 : 0.07) }
        GradientStop { position: 1; color: Commons.Util.alpha(root.high, 0) }
      }
      PathSvg {
        path: {
          var top = root.trace(0, root.bands - 1)
          return top ? top + " L " + root.width + " " + root.floorY + " L 0 " + root.floorY + " Z" : ""
        }
      }
    }

    ShapePath {
      fillColor: "transparent"
      strokeWidth: 1.2
      strokeColor: Commons.Util.alpha(root.low, root.playing ? 0.49 : 0.20)
      PathSvg { path: root.trace(0, Math.floor(root.bands * 0.33) - 1) }
    }

    ShapePath {
      fillColor: "transparent"
      strokeWidth: 1.2
      strokeColor: Commons.Util.alpha(root.mid, root.playing ? 0.45 : 0.16)
      PathSvg { path: root.trace(Math.floor(root.bands * 0.33), Math.floor(root.bands * 0.67) - 1) }
    }

    ShapePath {
      fillColor: "transparent"
      strokeWidth: 1.2
      strokeColor: Commons.Util.alpha(root.high, root.playing ? 0.49 : 0.20)
      PathSvg { path: root.trace(Math.floor(root.bands * 0.67), root.bands - 1) }
    }
  }

  Repeater {
    model: root.bands

    Item {
      id: band
      required property int index
      readonly property color tone: root.tones[index] || root.mid
      readonly property real level: root.levels[index] || 0.03
      readonly property real limit: root.headroom[index] || 0
      readonly property real stemHeight: Math.max(2, limit * level)
      readonly property real peakHeight: limit * (root.peaks[index] || level)

      x: (index + 0.5) * root.pitch - width / 2
      width: Math.max(1, root.pitch * 0.19)
      height: root.height
      opacity: Math.min(1, (index + 1) / 6, (root.bands - index) / 6)

      Rectangle {
        width: parent.width
        height: band.stemHeight
        y: root.floorY - height + 1
        opacity: root.playing ? 1 : 0.27
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.lighter(band.tone, 1.25) }
          GradientStop { position: 0.44; color: Commons.Util.alpha(band.tone, 0.71) }
          GradientStop { position: 1; color: Commons.Util.alpha(band.tone, 0.10) }
        }
      }

      Rectangle {
        width: parent.width
        height: Math.max(0, Math.min(root.height - root.floorY - 4, band.stemHeight * 0.12))
        y: root.floorY + 3
        opacity: 0.20 * Math.min(1, band.level * 1.65)
        color: band.tone
      }

      Rectangle {
        width: parent.width
        height: Math.max(1, width * 0.35)
        y: Math.max(2, root.floorY - band.peakHeight)
        visible: root.showPeaks && band.peakHeight - band.stemHeight > 6 && band.level > 0.1
        color: Commons.Util.alpha(Qt.lighter(band.tone, 1.34), 0.58)
      }
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    y: Math.round(root.floorY) + 1
    opacity: root.playing ? 0.51 : 0.20
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Commons.Util.alpha(root.low, 0) }
      GradientStop { position: 0.13; color: root.low }
      GradientStop { position: 0.50; color: root.mid }
      GradientStop { position: 0.87; color: root.high }
      GradientStop { position: 1; color: Commons.Util.alpha(root.high, 0) }
    }
  }
}
