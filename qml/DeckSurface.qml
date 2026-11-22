import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  required property color baseColor
  required property color accent
  property bool themed: false
  property bool emphasized: false

  radius: Style.space(11)
  color: Util.alpha(root.baseColor, 0.83)
  borderSpec: Border.flat(Util.alpha(root.accent, root.emphasized ? 0.30 : 0.14), 1)
  gradient: root.themed ? wash : null

  Gradient {
    id: wash
    GradientStop { position: 0; color: Qt.tint(root.baseColor, Util.alpha(root.accent, root.emphasized ? 0.10 : 0.065)) }
    GradientStop { position: 0.48; color: Qt.darker(root.baseColor, 1.16) }
    GradientStop { position: 1; color: Qt.darker(root.baseColor, 1.38) }
  }
}
