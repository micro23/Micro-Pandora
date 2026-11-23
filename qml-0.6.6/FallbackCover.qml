import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  required property color baseColor
  required property color accent
  required property color accentAlt

  Rectangle {
    anchors.fill: parent
    radius: Math.min(width, height) * 0.041
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Qt.tint(root.baseColor, Util.alpha(root.accentAlt, 0.18)) }
      GradientStop { position: 0.51; color: Qt.darker(root.baseColor, 1.40) }
      GradientStop { position: 1; color: Qt.tint(root.baseColor, Util.alpha(root.accent, 0.22)) }
    }
  }

  Repeater {
    model: [0.80, 0.69, 0.58, 0.47, 0.36]
    Rectangle {
      required property real modelData
      anchors.centerIn: parent
      width: Math.min(root.width, root.height) * modelData
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 1
      border.color: Util.alpha(root.accentAlt, 0.22)
    }
  }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(root.width, root.height) * 0.31
    height: width
    radius: width / 2
    color: Util.alpha(root.accent, 0.18)

    OpticalGlyph {
      anchors.centerIn: parent
      width: parent.width * 0.62
      height: width
      text: "󰎈"
      color: root.accent
      fontFamily: Style.font.family
      fontSize: width * 0.87
    }
  }
}
