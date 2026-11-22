import QtQuick
import qs.Commons as Commons

Canvas {
  id: root

  required property var levels
  required property var tones
  required property color guideColor
  required property bool playing
  required property bool motionEnabled

  readonly property real fullCircle: 2 * Math.PI
  readonly property real bass: meanLevel(0, 9)
  readonly property real high: meanLevel(Math.floor(levels.length * 0.68), levels.length)
  readonly property real energy: Math.max(bass, meanLevel(0, levels.length))
  readonly property bool moving: visible && playing && motionEnabled && energy > 0.073
  readonly property bool settling: visible && motionEnabled && !moving && (lift > 0.01 || waveAge < 1 || flash > 0.02 || Math.abs(orbitTilt) > 0.003)

  property real phase: 0
  property real bassFloor: 0
  property real lastAttack: 0
  property real lift: 0
  property real liftVelocity: 0
  property real flash: 0
  property real waveAge: 1
  property real beatStrength: 0
  property real orbitTilt: 0

  readonly property real originX: width / 2
  readonly property real originY: height * (0.59 - lift * 0.16)
  readonly property real radiusX: Math.min(width * 0.32, height * 1.85) * (1 + lift * 0.15)
  readonly property real radiusY: height * (0.205 + lift * 0.10)

  onLevelsChanged: if (visible && !moving) requestPaint()
  onTonesChanged: requestPaint()
  onGuideColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()
  onPlayingChanged: if (visible) requestPaint()
  onMotionEnabledChanged: if (!motionEnabled) resetMotion()
  onMovingChanged: {
    if (!moving) {
      bassFloor = 0
      lastAttack = 0
      liftVelocity = 0
    }
  }

  function meanLevel(first, last) {
    var total = 0
    var end = Math.min(last, levels.length)
    for (var i = first; i < end; i++) total += levels[i]
    return end > first ? total / (end - first) : 0
  }

  function resetMotion() {
    phase = 0
    bassFloor = 0
    lastAttack = 0
    lift = 0
    liftVelocity = 0
    flash = 0
    waveAge = 1
    beatStrength = 0
    orbitTilt = 0
    if (visible) requestPaint()
  }

  function advance(seconds) {
    var elapsed = Math.max(0.001, Math.min(0.036, seconds))
    var attack = Math.max(0, bass - bassFloor)
    bassFloor += (bass - bassFloor) * (1 - Math.exp(-elapsed * 4.0))
    if (attack > 0.12 && lastAttack <= 0.12 && waveAge >= 0.31) {
      waveAge = 0
      beatStrength = Math.min(1, attack * 2.6)
      flash = beatStrength
    }
    lastAttack = attack
    waveAge = Math.min(1, waveAge + elapsed * 1.75)
    flash *= Math.exp(-elapsed * 6.0)

    phase = (phase + elapsed * (0.88 + energy * 2.0 + high * 1.1)) % (fullCircle * 100)
    orbitTilt = Math.sin(phase * 0.83) * Math.min(0.48, energy * 0.55)
    var oscillation = 0.14 * energy * (1 + Math.sin(phase * 3.3))
    var target = Math.min(1, bass * 0.43 + attack * 1.48 + oscillation)
    liftVelocity += (target - lift) * elapsed * 162
    liftVelocity *= Math.exp(-elapsed * 8.8)
    lift = Math.max(0, Math.min(1, lift + liftVelocity * elapsed))
  }

  FrameAnimation {
    running: root.moving || root.settling
    onTriggered: {
      if (root.moving) root.advance(frameTime)
      else {
        var decay = Math.exp(-Math.min(0.05, frameTime) * 23)
        root.lift *= decay
        root.flash *= decay
        root.waveAge = Math.min(1, root.waveAge + Math.min(0.05, frameTime) * 2.8)
        root.orbitTilt *= decay
      }
      root.requestPaint()
    }
  }

  function point(angle, scale, offset) {
    var x = Math.cos(angle) * radiusX * scale
    var depth = Math.sin(angle)
    return [originX + x * 0.95, originY + depth * radiusY * scale + offset]
  }

  function trace(ctx, scale, start, sweep, offset) {
    var segments = Math.max(9, Math.ceil(68 * Math.abs(sweep) / fullCircle))
    ctx.beginPath()
    for (var i = 0; i <= segments; i++) {
      var position = point(start + sweep * i / segments, scale, offset)
      if (i === 0) ctx.moveTo(position[0], position[1])
      else ctx.lineTo(position[0], position[1])
    }
  }

  function ellipse(ctx, scale, offset) {
    var rx = radiusX * scale * 0.95
    var ry = radiusY * scale
    ctx.beginPath()
    ctx.ellipse(originX - rx, originY + offset - ry, rx * 2, ry * 2)
  }

  function gradient(ctx, low, middle, high) {
    var ink = ctx.createLinearGradient(originX - radiusX, 0, originX + radiusX, 0)
    ink.addColorStop(0, low)
    ink.addColorStop(0.21, high)
    ink.addColorStop(0.5, Commons.Util.alpha(middle, 0.74))
    ink.addColorStop(0.79, high)
    ink.addColorStop(1, low)
    return ink
  }

  function guide(ctx, scale, color, opacity, lineWidth, offset) {
    ellipse(ctx, scale, offset)
    ctx.strokeStyle = color
    ctx.lineWidth = lineWidth
    ctx.globalAlpha = opacity
    ctx.stroke()
    ctx.globalAlpha = 1
  }

  function sweep(ctx, scale, angle, span, tone, strength) {
    trace(ctx, scale, angle - span, span, 0)
    ctx.strokeStyle = Commons.Util.alpha(tone, strength * 0.24)
    ctx.lineWidth = 6
    ctx.stroke()
    ctx.strokeStyle = Commons.Util.alpha(Qt.lighter(tone, 1.14), strength)
    ctx.lineWidth = 1.9
    ctx.stroke()
    var head = point(angle, scale, 0)
    ctx.beginPath()
    ctx.arc(head[0], head[1], 2.4 + flash * 2, 0, fullCircle)
    ctx.fillStyle = Commons.Util.alpha(Qt.lighter(tone, 1.3), strength)
    ctx.fill()
  }

  function sweepPair(ctx, scale, angle, span, tone, strength) {
    sweep(ctx, scale, angle, span, tone, strength)
    sweep(ctx, scale, Math.PI - angle, -span, tone, strength)
  }

  function peakPair(ctx, angle, energy, tone, quiet) {
    var depth = 0.44 + 0.56 * (1 + Math.sin(angle)) / 2
    var start = point(angle, 1.026, 0)
    var finish = point(angle, 1.075 + energy * 0.29,
      -energy * height * (0.12 + 0.06 * lift))
    var startOther = 2 * originX - start[0]
    var finishOther = 2 * originX - finish[0]
    ctx.beginPath()
    ctx.moveTo(start[0], start[1])
    ctx.lineTo(finish[0], finish[1])
    ctx.moveTo(startOther, start[1])
    ctx.lineTo(finishOther, finish[1])
    ctx.strokeStyle = Commons.Util.alpha(tone, quiet * depth * (0.44 + energy * 0.54))
    ctx.lineWidth = 1 + energy * (0.8 + depth * 1.7)
    ctx.stroke()
    if (energy <= 0.39 || depth <= 0.6) return
    var tip = 1 + energy * 1.1
    ctx.fillStyle = Commons.Util.alpha(Qt.lighter(tone, 1.24), quiet * depth * 0.71)
    ctx.beginPath()
    ctx.arc(finish[0], finish[1], tip, 0, fullCircle)
    ctx.moveTo(finishOther + tip, finish[1])
    ctx.arc(finishOther, finish[1], tip, 0, fullCircle)
    ctx.fill()
  }

  function light(ctx, x, y, radius, tone, strength) {
    var glow = ctx.createRadialGradient(x, y, 0, x, y, radius)
    glow.addColorStop(0, Commons.Util.alpha(tone, strength))
    glow.addColorStop(0.29, Commons.Util.alpha(tone, strength * 0.43))
    glow.addColorStop(1, Commons.Util.alpha(tone, 0))
    ctx.fillStyle = glow
    ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2)
  }

  function beatRings(ctx, ink, tone) {
    if (waveAge >= 1) return
    var outward = 1 - Math.pow(1 - waveAge, 1.7)
    var fade = beatStrength * Math.pow(1 - waveAge, 1.6)
    guide(ctx, 0.58 + outward * 0.95, ink, 0.74 * fade, 1 + fade * 2, 0)
    guide(ctx, 0.34 + outward * 0.97, tone, 0.36 * fade, 1, -height * outward * 0.05)
  }

  function sparks(ctx, tone, count, quiet) {
    if (high < 0.08 && waveAge >= 1) return
    var pulse = waveAge < 1 ? beatStrength * (1 - waveAge) : 0
    for (var i = 0; i < count; i++) {
      var travel = (phase * (0.24 + (i % 3) * 0.035) + i / count) % 1
      var angle = (i * 2.39996 + phase * 0.74) % fullCircle
      var scale = 0.97 + travel * (0.16 + pulse * 0.3)
      var offset = -height * (0.02 + travel * 0.22) * (high + pulse + 0.2)
      var spark = point(angle, scale, offset)
      var tail = point(angle - 0.16, scale - travel * 0.064, offset + height * travel * 0.018)
      var alpha = quiet * Math.sin(Math.PI * travel) * Math.min(0.76, high * 1.15 + pulse * 0.54)
      ctx.beginPath()
      ctx.moveTo(tail[0], tail[1])
      ctx.lineTo(spark[0], spark[1])
      ctx.strokeStyle = Commons.Util.alpha(tone, alpha * 0.62)
      ctx.lineWidth = 1 + pulse * 1.3
      ctx.stroke()
      ctx.beginPath()
      ctx.arc(spark[0], spark[1], 0.9 + alpha * 1.9, 0, fullCircle)
      ctx.fillStyle = Commons.Util.alpha(tone, alpha)
      ctx.fill()
    }
  }

  function coreRings(ctx, size, edge, outer, quiet) {
    ctx.save()
    ctx.translate(originX, originY)
    for (var i = 0; i < 2; i++) {
      var angle = (i === 0 ? 0.54 : -0.69) + orbitTilt * (i === 0 ? 1 : -1)
      var ratio = motionEnabled ? 0.44 + Math.sin(phase * 1.4 + i * 2.3) * energy * 0.23 : 0.44
      var radius = size * (0.62 + i * 0.22 + flash * 0.19)
      ctx.save()
      ctx.rotate(angle)
      ctx.scale(1, ratio)
      ctx.beginPath()
      ctx.arc(0, 0, radius, 0, fullCircle)
      ctx.strokeStyle = Commons.Util.alpha(i === 0 ? edge : outer, quiet * (0.45 + flash * 0.31))
      ctx.lineWidth = 1.65
      ctx.stroke()
      var position = (i === 0 ? phase * 2.4 : -phase * 2.1) + i * 2.4
      ctx.beginPath()
      ctx.arc(Math.cos(position) * radius, Math.sin(position) * radius, 2.5 + flash * 1.7, 0, fullCircle)
      ctx.fillStyle = Commons.Util.alpha(Qt.lighter(i === 0 ? edge : outer, 1.3), quiet * 0.82)
      ctx.fill()
      ctx.restore()
    }
    ctx.restore()
  }

  onPaint: {
    var ctx = getContext("2d")
    if (!ctx || width <= 0 || height <= 0) return
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    var count = Math.min(levels.length, tones.length)
    if (count < 2) return

    var quiet = playing ? 1 : 0.34
    var edge = tones[Math.floor(count * 0.12)]
    var outer = tones[Math.floor(count * 0.62)]
    var inner = tones[Math.floor(count * 0.36)]
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    var ringInk = gradient(ctx, edge, inner, outer)

    // The floor stays in place while the orbit lifts above it.
    ctx.save()
    ctx.translate(0, height * 0.60)
    ctx.scale(1, 0.26)
    light(ctx, originX, height * 0.57, radiusX * 0.78, inner, quiet * (0.19 + flash * 0.26))
    ctx.restore()
    guide(ctx, 1.16, ringInk, 0.17 * quiet, 1, height * (0.11 + lift * 0.15))
    guide(ctx, 0.93, ringInk, 0.10 * quiet, 1, height * (0.15 + lift * 0.15))

    ellipse(ctx, 1, 0)
    ctx.fillStyle = ringInk
    ctx.globalAlpha = 0.073 * quiet
    ctx.fill()
    ctx.globalAlpha = 1
    guide(ctx, 1.18, ringInk, 0.29 * quiet, 1, 0)
    guide(ctx, 1.00, ringInk, (0.57 + flash * 0.25) * quiet, 1.45, 0)
    guide(ctx, 0.77, ringInk, 0.29 * quiet, 1, 0)
    guide(ctx, 0.51, ringInk, 0.23 * quiet, 1, 0)
    beatRings(ctx, ringInk, edge)

    // Mirrored slots share the same energy. Moving the sampled frequencies
    // around both sides keeps the Orbit centered even on a hard bass hit.
    var pairCount = Math.ceil(count / 2)
    for (var band = 0; band < pairCount; band++) {
      var angle = ((band + 0.5) / pairCount - 0.5) * Math.PI
      var sample = (band * count / pairCount + phase / fullCircle * count * 0.34) % count
      var lo = Math.floor(sample)
      var hi = (lo + 1) % count
      var mix = sample - lo
      var energy = levels[lo] + (levels[hi] - levels[lo]) * mix
      var tone = Qt.tint(tones[lo], Commons.Util.alpha(tones[hi], mix))
      peakPair(ctx, angle, energy, tone, quiet)
    }

    sweepPair(ctx, 0.78, phase * 1.52 + 0.4, 0.62 + bass * 0.69, edge, quiet * 0.78)
    sweepPair(ctx, 0.53, -phase * 2.14 - 2.2, 0.44 + high * 0.75, outer, quiet * 0.73)
    sweepPair(ctx, 1.00, -phase * 0.84 + 2.26, 0.37 + bass * 0.52, inner, quiet * 0.68)

    if (motionEnabled && playing) sparks(ctx, Qt.lighter(outer, 1.31), 18, quiet)

    var size = Math.max(14, height * (0.093 + lift * 0.075))
    light(ctx, originX, originY, size * 2.0, guideColor, quiet * (0.38 + flash * 0.42))
    ctx.beginPath()
    ctx.arc(originX, originY, size * (0.20 + flash * 0.07), 0, fullCircle)
    ctx.fillStyle = Commons.Util.alpha(Qt.lighter(guideColor, 1.32), quiet * (0.73 + flash * 0.25))
    ctx.fill()
    coreRings(ctx, size, edge, outer, quiet)
  }
}
