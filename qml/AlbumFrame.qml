import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  required property color foreground
  required property color accent
  required property color accentAlt
  property bool tinted: false
  property bool glow: false

  borderSpec: {
    if (!root.tinted) return Border.controlSpec("normal", root.foreground, root.accent)
    var outline = Border.flat(Util.alpha(root.accent, 0.55), Math.max(1, Style.space(2)))
    outline.gradient = {
      colors: [Util.alpha(root.foreground, 0.50), Util.alpha(root.accentAlt, 0.62),
        Util.alpha(root.foreground, 0.20), Util.alpha(root.accent, 0.64)],
      angle: 45,
      enabled: true
    }
    return outline
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -Style.space(6)
    radius: root.radius + Style.space(5)
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.accentAlt, 0.24)
    visible: root.glow
    z: -1
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -Style.space(11)
    radius: root.radius + Style.space(10)
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.accent, 0.09)
    visible: root.glow
    z: -1
  }
}
