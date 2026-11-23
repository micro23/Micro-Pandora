import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  required property color baseColor
  required property color accent
  property bool themed: false
  property bool emphasized: false
  property bool litEdge: false
  property color secondaryAccent: accent

  radius: Style.space(11)
  color: Util.alpha(root.baseColor, 0.83)
  borderSpec: Border.flat(Util.alpha(root.accent, root.emphasized ? 0.30 : 0.14), 1)
  gradient: root.themed ? wash : null

  Gradient {
    id: wash
    GradientStop { position: 0; color: Qt.tint(root.baseColor, Util.alpha(root.accent, root.emphasized ? 0.13 : 0.083)) }
    GradientStop { position: 0.46; color: Qt.darker(root.baseColor, 1.18) }
    GradientStop { position: 1; color: Qt.tint(Qt.darker(root.baseColor, 1.43), Util.alpha(root.secondaryAccent, 0.035)) }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: root.radius
    anchors.rightMargin: root.radius
    anchors.topMargin: 1
    height: 1
    visible: root.litEdge
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Util.alpha(root.accent, 0) }
      GradientStop { position: 0.21; color: Util.alpha(root.accent, 0.33) }
      GradientStop { position: 0.75; color: Util.alpha(root.secondaryAccent, 0.26) }
      GradientStop { position: 1; color: Util.alpha(root.secondaryAccent, 0) }
    }
  }
}
