import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  required property color baseColor
  required property color accent
  property bool themed: false
  property bool emphasized: false

  radius: Style.cornerRadius
  color: Util.alpha(root.baseColor, 0.76)
  borderSpec: Border.flat(Util.alpha(root.accent, root.emphasized ? 0.54 : 0.23), 1)
  gradient: root.themed ? wash : null

  Gradient {
    id: wash
    GradientStop { position: 0; color: Qt.tint(root.baseColor, Util.alpha(root.accent, root.emphasized ? 0.19 : 0.12)) }
    GradientStop { position: 1; color: Qt.darker(root.baseColor, 1.5) }
  }
}
