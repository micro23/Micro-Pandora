import QtQuick
import qs.Commons as Commons

Canvas {
  id: root

  required property color baseColor
  required property color primary
  required property color secondary
  property real horizon: 0.80
  property real cornerRadius: 0

  onBaseColorChanged: requestPaint()
  onPrimaryChanged: requestPaint()
  onSecondaryChanged: requestPaint()
  onHorizonChanged: requestPaint()
  onCornerRadiusChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  function light(ctx, x, y, radius, color, strength) {
    var glow = ctx.createRadialGradient(x, y, 0, x, y, radius)
    glow.addColorStop(0, Commons.Util.alpha(color, strength))
    glow.addColorStop(0.46, Commons.Util.alpha(color, strength * 0.46))
    glow.addColorStop(1, Commons.Util.alpha(color, 0))
    ctx.fillStyle = glow
    ctx.fillRect(0, 0, width, height)
  }

  onPaint: {
    var ctx = getContext("2d")
    if (!ctx || width <= 0 || height <= 0) return
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    var radius = Math.min(cornerRadius, width / 2, height / 2)
    if (radius > 0) {
      ctx.beginPath()
      ctx.moveTo(radius, 0)
      ctx.lineTo(width - radius, 0)
      ctx.quadraticCurveTo(width, 0, width, radius)
      ctx.lineTo(width, height - radius)
      ctx.quadraticCurveTo(width, height, width - radius, height)
      ctx.lineTo(radius, height)
      ctx.quadraticCurveTo(0, height, 0, height - radius)
      ctx.lineTo(0, radius)
      ctx.quadraticCurveTo(0, 0, radius, 0)
      ctx.closePath()
      ctx.clip()
    }

    var wash = ctx.createLinearGradient(0, 0, width * 0.42, height)
    wash.addColorStop(0, Qt.tint(baseColor, Qt.rgba(0, 0, 0, 0.42)))
    wash.addColorStop(0.58, Qt.tint(baseColor, Qt.rgba(0, 0, 0, 0.62)))
    wash.addColorStop(1, Qt.tint(baseColor, Qt.rgba(0, 0, 0, 0.76)))
    ctx.fillStyle = wash
    ctx.fillRect(0, 0, width, height)

    light(ctx, width * 0.24, height * 0.31, width * 0.52, secondary, 0.18)
    light(ctx, width * 0.83, height * 0.38, width * 0.54, primary, 0.21)
    light(ctx, width * 0.50, height * horizon, width * 0.39, primary, 0.10)

    var y = height * horizon
    var grid = ctx.createLinearGradient(0, y, 0, height)
    grid.addColorStop(0, Commons.Util.alpha(secondary, 0))
    grid.addColorStop(0.38, Commons.Util.alpha(secondary, 0.09))
    grid.addColorStop(1, Commons.Util.alpha(primary, 0.15))
    ctx.strokeStyle = grid
    ctx.lineWidth = 1
    ctx.beginPath()
    for (var i = -8; i <= 8; i++) {
      ctx.moveTo(width * (0.50 + i * 0.026), y)
      ctx.lineTo(width * (0.50 + i * 0.119), height)
    }
    for (var line = 1; line <= 5; line++) {
      var at = Math.round(y + (height - y) * Math.pow(line / 5.4, 1.8)) + 0.5
      ctx.moveTo(0, at)
      ctx.lineTo(width, at)
    }
    ctx.stroke()
  }
}
