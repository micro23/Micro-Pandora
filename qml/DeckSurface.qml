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
  borderSpec: {
    var outline = Border.flat(Util.alpha(root.accent, root.emphasized ? 0.50 : 0.24), 1)
    if (root.themed && root.emphasized) {
      outline.gradient = {
        colors: [Util.alpha(root.accent, 0.72), Util.alpha(root.accent, 0.24)],
        angle: 45,
        enabled: true
      }
    }
    return outline
  }
  gradient: root.themed ? wash : null

  Gradient {
    id: wash
    GradientStop { position: 0; color: Qt.tint(root.baseColor, Util.alpha(root.accent, root.emphasized ? 0.19 : 0.12)) }
    GradientStop { position: 0.16; color: Qt.tint(root.baseColor, Util.alpha(root.accent, root.emphasized ? 0.13 : 0.07)) }
    GradientStop { position: 1; color: Qt.darker(root.baseColor, 1.64) }
  }
}
