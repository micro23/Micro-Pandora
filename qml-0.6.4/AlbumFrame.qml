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
  property real lightLevel: 0

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

  Loader {
    anchors.fill: parent
    anchors.margins: -Style.space(48)
    z: -2
    active: root.glow && root.visible
    opacity: 0.52 + Math.min(1, Math.max(0, root.lightLevel)) * 0.39

    sourceComponent: Canvas {
      readonly property color glowLeft: root.accentAlt
      readonly property color glowRight: root.accent

      onGlowLeftChanged: requestPaint()
      onGlowRightChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      function spot(ctx, x, y, radius, color) {
        var halo = ctx.createRadialGradient(x, y, 0, x, y, radius)
        halo.addColorStop(0, Util.alpha(color, 0.33))
        halo.addColorStop(0.50, Util.alpha(color, 0.17))
        halo.addColorStop(1, Util.alpha(color, 0))
        ctx.fillStyle = halo
        ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2)
      }

      onPaint: {
        var ctx = getContext("2d")
        if (!ctx || width <= 0 || height <= 0) return
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        spot(ctx, width * 0.37, height * 0.57, width * 0.48, glowLeft)
        spot(ctx, width * 0.66, height * 0.54, width * 0.44, glowRight)
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -Style.space(6)
    radius: root.radius + Style.space(5)
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.accentAlt, 0.24 + root.lightLevel * 0.25)
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
