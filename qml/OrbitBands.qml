import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons

Item {
  id: root

  required property var levels
  required property var tones
  required property color guideColor
  required property bool playing
  readonly property real radiusX: Math.min(width * 0.36, height * 1.18)
  readonly property real radiusY: height * 0.27
  readonly property real energy: {
    var sum = 0
    var count = Math.min(levels.length, 12)
    for (var i = 0; i < count; i++) sum += levels[i]
    return count ? sum / count : 0
  }

  Shape {
    anchors.fill: parent
    visible: root.visible && root.levels.length > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeWidth: 1
      strokeColor: Commons.Util.alpha(root.guideColor, 0.25)
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.radiusX
        radiusY: root.radiusY
        startAngle: 0
        sweepAngle: 360
      }
    }
    ShapePath {
      fillColor: "transparent"
      strokeWidth: 1
      strokeColor: Commons.Util.alpha(root.guideColor, 0.12)
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.radiusX * 0.74
        radiusY: root.radiusY * 0.74
        startAngle: 0
        sweepAngle: 360
      }
    }
    ShapePath {
      strokeWidth: -1
      fillGradient: RadialGradient {
        centerX: root.width / 2
        centerY: root.height / 2
        centerRadius: root.radiusY * (1.3 + root.energy)
        focalX: centerX
        focalY: centerY
        GradientStop { position: 0; color: Commons.Util.alpha(root.guideColor, root.playing ? 0.30 : 0.08) }
        GradientStop { position: 1; color: Commons.Util.alpha(root.guideColor, 0) }
      }
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.radiusX * 0.74
        radiusY: root.radiusY * 0.74
        startAngle: 0
        sweepAngle: 360
      }
    }
  }

  Repeater {
    model: Math.min(root.levels.length, root.tones.length)
    Rectangle {
      id: radialBand
      required property int index
      readonly property real angle: index / root.levels.length * 2 * Math.PI - Math.PI / 2
      readonly property color tone: root.tones[index]
      width: Math.max(3, Math.min(Commons.Style.space(8), root.height * 0.041))
      height: width + root.height * 0.19 * root.levels[index]
      x: root.width / 2 + Math.cos(angle) * root.radiusX - width / 2
      y: root.height / 2 + Math.sin(angle) * root.radiusY - height
      rotation: (angle + Math.PI / 2) * 180 / Math.PI
      transformOrigin: Item.Bottom
      radius: width / 2
      opacity: root.playing ? 0.94 : 0.30
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(radialBand.tone, 1.28) }
        GradientStop { position: 1; color: Qt.darker(radialBand.tone, 1.65) }
      }
    }
  }
}
