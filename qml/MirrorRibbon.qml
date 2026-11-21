import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons

Item {
  id: root

  required property var levels
  required property color low
  required property color mid
  required property color high
  required property bool playing
  required property real centerHeight
  required property var heightLimit
  readonly property real centerLine: height - centerHeight / 2
  readonly property var envelope: {
    var bands = []
    for (var first = 0; first < levels.length; first += 2) {
      var a = levels[first]
      var b = levels[first + 1] ?? a
      bands.push(Math.max(a, b) * 0.68 + Math.min(a, b) * 0.32)
    }
    return bands
  }

  function bandY(index, distance, reflected) {
    if (index >= envelope.length) return centerLine
    if (reflected) return centerLine + centerHeight * 0.39 * envelope[index]
    var availableHeight = heightLimit((index + 1) * distance, distance)
    return centerLine - Math.min(availableHeight * 0.52, centerLine * 0.84) * envelope[index]
  }

  function lobe(reflected) {
    if (envelope.length < 2 || width <= 0) return ""
    var path = ["M 0", centerLine]
    var distance = width / (envelope.length + 1)
    for (var i = 0; i < envelope.length; i++) {
      var x = (i + 1) * distance
      var y = bandY(i, distance, reflected)
      var nextY = bandY(i + 1, distance, reflected)
      path.push("Q", x.toFixed(1), y.toFixed(1), (x + distance / 2).toFixed(1),
                ((y + nextY) / 2).toFixed(1))
    }
    path.push("L", width, centerLine, "Z")
    return path.join(" ")
  }

  Rectangle {
    width: parent.width
    height: 1
    y: root.centerLine
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Commons.Util.alpha(root.low, 0) }
      GradientStop { position: 0.5; color: Commons.Util.alpha(root.mid, 0.30) }
      GradientStop { position: 1; color: Commons.Util.alpha(root.high, 0) }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.envelope.length > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: Commons.Util.alpha(Qt.lighter(root.mid, 1.18), root.playing ? 0.78 : 0.34)
      strokeWidth: root.playing ? 1.45 : 1
      joinStyle: ShapePath.RoundJoin
      fillGradient: LinearGradient {
        x2: root.width
        GradientStop { position: 0; color: Commons.Util.alpha(root.low, 0.67) }
        GradientStop { position: 0.5; color: Commons.Util.alpha(root.mid, 0.40) }
        GradientStop { position: 1; color: Commons.Util.alpha(root.high, 0.58) }
      }
      PathSvg { path: root.lobe(false) }
    }

    ShapePath {
      strokeColor: Commons.Util.alpha(root.mid, root.playing ? 0.28 : 0.14)
      strokeWidth: 1
      joinStyle: ShapePath.RoundJoin
      fillGradient: LinearGradient {
        x2: root.width
        GradientStop { position: 0; color: Commons.Util.alpha(root.low, 0.19) }
        GradientStop { position: 0.5; color: Commons.Util.alpha(root.mid, 0.14) }
        GradientStop { position: 1; color: Commons.Util.alpha(root.high, 0.18) }
      }
      PathSvg { path: root.lobe(true) }
    }
  }
}
