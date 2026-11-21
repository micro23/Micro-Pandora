import QtQuick
import QtQuick.Effects
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
    var outline = Border.flat(Util.alpha(root.accent, 0.72), Style.space(2))
    outline.gradient = {
      colors: [Util.alpha(root.accent, 0.80), Util.alpha(root.accentAlt, 0.78)],
      angle: 45,
      enabled: true
    }
    return outline
  }

  layer.enabled: root.tinted && root.glow
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Util.alpha(root.accentAlt, 0.36)
    shadowBlur: 1
    shadowVerticalOffset: Style.space(7)
    blurMax: 24
    blurMultiplier: 1
  }
}
