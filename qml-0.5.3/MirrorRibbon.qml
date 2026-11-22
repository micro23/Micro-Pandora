import QtQuick
import qs.Commons as Commons

Canvas {
  id: root

  required property var levels
  required property var peakLevels
  required property color low
  required property color mid
  required property color high
  required property bool playing
  required property real centerHeight
  required property var heightLimit

  onLevelsChanged: if (visible) requestPaint()
  onPeakLevelsChanged: if (visible) requestPaint()
  onLowChanged: requestPaint()
  onMidChanged: requestPaint()
  onHighChanged: requestPaint()
  onPlayingChanged: requestPaint()
  onCenterHeightChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  function colors(ctx, alpha) {
    var glow = ctx.createLinearGradient(0, 0, width, 0)
    glow.addColorStop(0, Commons.Util.alpha(low, 0))
    glow.addColorStop(0.15, Commons.Util.alpha(low, alpha))
    glow.addColorStop(0.49, Commons.Util.alpha(mid, alpha * 0.65))
    glow.addColorStop(0.85, Commons.Util.alpha(high, alpha))
    glow.addColorStop(1, Commons.Util.alpha(high, 0))
    return glow
  }

  function trace(ctx, points, baseline, multiplier) {
    var dx = width / (points.length + 1)
    ctx.moveTo(0, baseline)
    for (var i = 0; i < points.length; i++) {
      var x = (i + 1) * dx
      var current = points[i]
      var next = points[i + 1] || 0
      ctx.quadraticCurveTo(x, baseline + current * multiplier,
        x + dx * 0.5, baseline + (current + next) * multiplier * 0.5)
    }
    ctx.lineTo(width, baseline)
  }

  function ribbon(ctx, points, baseline, multiplier, opacity, fill) {
    ctx.beginPath()
    trace(ctx, points, baseline, multiplier)
    if (fill) {
      ctx.closePath()
      ctx.fillStyle = colors(ctx, opacity * 0.21)
      ctx.fill()
    }
    ctx.strokeStyle = colors(ctx, opacity)
    ctx.lineWidth = fill && multiplier < 0 ? 1.8 : 1
    ctx.stroke()
  }

  onPaint: {
    var ctx = getContext("2d")
    if (!ctx || width <= 0 || height <= 0) return
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    if (levels.length < 4) return

    var axis = height - centerHeight * 0.44
    var points = []
    var trails = []
    var reflections = []
    var strongest = 0
    var bandCount = Math.ceil(levels.length / 2)
    for (var index = 0; index < bandCount; index++) {
      var a = levels[index * 2]
      var b = levels[index * 2 + 1] ?? a
      var energy = Math.max(a, b) * 0.66 + Math.min(a, b) * 0.34
      var x = (index + 1) * width / (bandCount + 1)
      var allowance = Math.min(axis * 0.73, heightLimit(x, 0) * 0.66)
      var levelHeight = playing ? allowance : centerHeight * 0.22
      var peak = Math.max(peakLevels[index * 2] || a, peakLevels[index * 2 + 1] || b)
      points.push(3 + energy * levelHeight)
      trails.push(3 + (energy * 0.50 + peak * 0.50) * levelHeight)
      reflections.push(2 + energy * Math.min(levelHeight * 0.46, centerHeight * 0.42))
      strongest = Math.max(strongest, energy)
    }

    var strength = playing ? 0.74 + strongest * 0.26 : 0.34
    ribbon(ctx, reflections, axis, 1.0, strength * 0.57, true)
    ribbon(ctx, reflections, axis, 0.58, strength * 0.26, false)
    if (peakLevels.length) ribbon(ctx, trails, axis, -1.0, strength * 0.30, false)

    ctx.beginPath()
    trace(ctx, points, axis, -1.0)
    ctx.strokeStyle = colors(ctx, strength * 0.19)
    ctx.lineWidth = 7.5
    ctx.stroke()
    ribbon(ctx, points, axis, -1.0, strength, true)
    ribbon(ctx, points, axis, -0.78, strength * 0.39, false)
    ribbon(ctx, points, axis, -0.53, strength * 0.31, false)
    ribbon(ctx, points, axis, -0.30, strength * 0.21, false)

    ctx.fillStyle = colors(ctx, strength * 0.68)
    ctx.fillRect(0, Math.round(axis), width, 1)
    ctx.fillStyle = colors(ctx, strength * 0.44)
    var dx = width / 40
    for (var tick = 1; tick < 40; tick++) {
      var tickHeight = tick % 5 === 0 ? 6 : 3
      ctx.fillRect(Math.round(tick * dx), axis + 2, 1, tickHeight)
    }
  }
}
