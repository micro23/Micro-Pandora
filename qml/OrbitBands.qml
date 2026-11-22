import QtQuick
import qs.Commons as Commons

Canvas {
  id: root

  required property var levels
  required property var tones
  required property color guideColor
  required property bool playing

  readonly property real originX: width / 2
  readonly property real originY: height * 0.57
  readonly property real radiusX: Math.min(width * 0.37, height * 2.05)
  readonly property real radiusY: height * 0.25
  readonly property real tilt: -0.095
  readonly property real fullCircle: 2 * Math.PI

  onLevelsChanged: if (visible) requestPaint()
  onTonesChanged: requestPaint()
  onGuideColorChanged: requestPaint()
  onPlayingChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  function project(angle, scale, offset) {
    var x = Math.cos(angle) * radiusX * scale
    var y = Math.sin(angle) * radiusY * scale
    return [originX + x, originY + y + x * tilt + offset]
  }

  function ring(ctx, scale, start, sweep, offset) {
    var segments = Math.max(12, Math.ceil(76 * Math.abs(sweep) / fullCircle))
    ctx.beginPath()
    for (var i = 0; i <= segments; i++) {
      var point = project(start + sweep * i / segments, scale, offset)
      if (i === 0) ctx.moveTo(point[0], point[1])
      else ctx.lineTo(point[0], point[1])
    }
  }

  function guide(ctx, scale, alpha, offset) {
    ring(ctx, scale, 0, fullCircle, offset)
    ctx.strokeStyle = Commons.Util.alpha(guideColor, alpha)
    ctx.lineWidth = 1
    ctx.stroke()
  }

  onPaint: {
    var ctx = getContext("2d")
    if (!ctx || width <= 0 || height <= 0) return
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    var count = Math.min(levels.length, tones.length)
    if (count < 2) return

    var bass = 0
    var upper = 0
    for (var i = 0; i < 8; i++) {
      bass += levels[i] || 0
      upper += levels[count - i - 1] || 0
    }
    bass /= 8
    upper /= 8

    var core = ctx.createRadialGradient(originX, originY, 0, originX, originY, radiusX * 0.58)
    core.addColorStop(0, Commons.Util.alpha(guideColor, playing ? 0.20 + bass * 0.18 : 0.08))
    core.addColorStop(0.44, Commons.Util.alpha(guideColor, 0.07))
    core.addColorStop(1, Commons.Util.alpha(guideColor, 0))
    ctx.save()
    ctx.translate(0, originY * 0.63)
    ctx.scale(1, 0.37)
    ctx.fillStyle = core
    ctx.fillRect(0, 0, width, height * 2)
    ctx.restore()

    guide(ctx, 1.22, 0.18, 0)
    guide(ctx, 1.00, 0.35, 0)
    guide(ctx, 0.80, 0.24, 0)
    guide(ctx, 0.57, 0.14, 0)
    guide(ctx, 0.43, 0.11, 0)
    guide(ctx, 1.00, 0.12, height * 0.12)
    guide(ctx, 0.80, 0.07, height * 0.12)

    var accents = [tones[Math.floor(count * 0.18)], tones[Math.floor(count * 0.68)]]
    for (var arc = 0; arc < accents.length; arc++) {
      var response = arc === 0 ? bass : upper
      ring(ctx, 0.79 - arc * 0.16, 0.40 + arc * Math.PI, Math.PI * (0.42 + response * 0.48), 0)
      ctx.strokeStyle = Commons.Util.alpha(accents[arc], playing ? 0.54 + response * 0.29 : 0.24)
      ctx.lineWidth = arc === 0 ? 2.2 : 1.5
      ctx.stroke()
    }

    for (var band = 0; band < count; band++) {
      var angle = band / count * fullCircle
      var front = 0.57 + 0.43 * (1 + Math.sin(angle)) / 2
      var level = levels[band]
      var at = project(angle, 1.035, 0)
      var out = project(angle, 1.07 + (playing ? level * 0.25 : 0), 0)
      var tone = tones[band]
      ctx.beginPath()
      ctx.moveTo(at[0], at[1])
      ctx.lineTo(out[0], out[1] - level * (playing ? height * 0.13 : 0))
      ctx.strokeStyle = Commons.Util.alpha(tone, (playing ? 0.50 + level * 0.49 : 0.28) * front)
      ctx.lineWidth = playing && level > 0.70 ? 2.5 : 1.35
      ctx.stroke()

      if (band % 7 === 0) {
        var checkpoint = project(angle, 0.80, 0)
        ctx.beginPath()
        ctx.arc(checkpoint[0], checkpoint[1], 1.5, 0, fullCircle)
        ctx.fillStyle = Commons.Util.alpha(Qt.lighter(tone, 1.25), playing ? front * 0.73 : 0.30)
        ctx.fill()
      }
    }

    var sol = Commons.Util.alpha(guideColor, playing ? 0.46 + bass * 0.45 : 0.28)
    ctx.beginPath()
    ctx.arc(originX, originY, Math.max(2, height * (0.010 + bass * 0.014)), 0, fullCircle)
    ctx.fillStyle = sol
    ctx.fill()
  }
}
