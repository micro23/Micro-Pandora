import QtQuick

// LyricsStage — lyrics for the full player's Now Playing pane.
// Under the album art, the song's words slide right to left. The word being sung
// drops out of that strip, big, into the middle of the pane, then floats back
// up into its spot in the strip when the next word drops.
//
// lrclib only times whole lines, so each line's words are spread over the
// line by syllables.
Item {
  id: stage

  property var lines: []              // [{ time, text }] from the service
  property real position: 0           // play position the service reports, seconds
  property bool playing: false
  property bool active: visible
  property color foreground: "white"
  property color accent: "white"
  property color muted: "gray"
  property string fontFamily: ""
  property real tickerHeight: 34      // the strip of words
  property real tickerY: 0            // where the strip sits (under the album art)
  property real bigCenterY: height / 2 // where the big word sits
  property int bigSize: 64
  property int tickerSize: 18

  // ── Words with estimated times ────────────────
  // Rough syllable count: groups of vowels (a trailing silent e doesn't count).
  function syllables(word) {
    var w = String(word).toLowerCase().replace(/[^a-z]/g, "")
    if (!w) return 1
    var n = (w.replace(/e$/, "").match(/[aeiouy]+/g) || []).length
    return Math.max(1, n)
  }
  readonly property var words: {
    var out = []
    for (var i = 0; i < lines.length; i++) {
      var t = lines[i].time
      var end = i + 1 < lines.length ? lines[i + 1].time : t + 4
      var parts = String(lines[i].text || "").split(/\s+/).filter(function(w) { return w !== "" })
      if (!parts.length) { out.push({ text: "♪", time: t, line: i }); continue }
      // Spread the words over the whole line, by syllables (singers hold long
      // words longer). A line followed by a long instrumental gap stops after
      // a sensible singing time instead of stretching into the gap.
      var syl = parts.map(stage.syllables)
      var total = syl.reduce(function(n, v) { return n + v }, 0)
      var gap = end - t
      var span = Math.min(gap * 0.92, Math.max(1.0, total * 0.42 + 0.8))
      var at = t
      for (var k = 0; k < parts.length; k++) {
        out.push({ text: parts[k], time: at, line: i })
        at += span * syl[k] / total
      }
    }
    return out
  }

  // Smooth position between the service's reports.
  // A report a hair behind our running clock is ignored (it would step the
  // word back); a real jump (seek, new song) is taken as is.
  property real smooth: 0
  property real base: 0
  property real stamp: 0
  onPositionChanged: {
    var est = playing ? base + (Date.now() - stamp) / 1000 : smooth
    base = (position < est && est - position < 0.8) ? est : position
    stamp = Date.now()
    smooth = base
  }
  // pause/resume: the clock picks up where it stopped
  onPlayingChanged: { base = smooth; stamp = Date.now() }
  Timer {
    interval: 40
    repeat: true
    running: stage.active && stage.playing && stage.words.length > 0
    onTriggered: stage.smooth = stage.base + (Date.now() - stage.stamp) / 1000
  }

  readonly property int current: {
    var i = -1
    for (var k = 0; k < words.length; k++) {
      if (words[k].time <= smooth + 0.05) i = k
      else break
    }
    return i
  }

  // ── The strip across the top ──────────────────
  function slotCenter(i) {
    var it = strip.itemAt(i)
    return it ? it.x + it.width / 2 : 0
  }
  // Where word i sits on screen (stage coordinates) once the strip is
  // centered on word c.
  function slotX(i, c) { return width / 2 + slotCenter(i) - slotCenter(Math.max(0, c)) }
  readonly property real tickerMid: tickerY + tickerHeight / 2

  Item {
    id: tickerClip
    y: stage.tickerY
    width: parent.width
    height: stage.tickerHeight
    clip: true

    Row {
      id: row
      spacing: 14
      height: parent.height
      x: stage.words.length ? stage.width / 2 - stage.slotCenter(Math.max(0, stage.current)) : 0
      Behavior on x {
        enabled: !stage.jumped
        NumberAnimation { duration: 380; easing.type: Easing.InOutQuad }
      }
      Repeater {
        id: strip
        model: stage.words
        Text {
          required property var modelData
          required property int index
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.text
          textFormat: Text.PlainText
          color: stage.foreground
          // fades out the farther it is from the middle
          readonly property int dist: Math.abs(index - stage.current)
          opacity: index === stage.current ? 0 : Math.max(0.15, (index < stage.current ? 0.55 : 0.9) - dist * 0.045)
          font.family: stage.fontFamily
          font.pixelSize: stage.tickerSize
          Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
        }
      }
    }

  }

  // ── The big word (two that take turns) ────────
  // One drops down from the strip; the other, the word before, floats back up.
  property bool jumped: false
  property int lastWord: -1
  property bool useA: true

  component Flyer: Text {
    id: f
    property real cx: 0
    property real cy: 0
    property real s: 1
    x: cx - width / 2
    y: cy - height / 2
    scale: s
    opacity: 0
    textFormat: Text.PlainText
    color: stage.accent
    font.family: stage.fontFamily
    font.pixelSize: stage.bigSize
    font.bold: true
    function drop(word, fromX) {
      text = word
      dropAnim.stop(); riseAnim.stop()
      dropAnim.fromX = fromX
      dropAnim.start()
    }
    function rise(toX) {
      if (opacity <= 0) return
      dropAnim.stop()
      riseAnim.toX = toX
      riseAnim.start()
    }
    function hide() { dropAnim.stop(); riseAnim.stop(); opacity = 0 }
    function show(word) { dropAnim.stop(); riseAnim.stop(); text = word; cx = stage.width / 2; cy = stage.bigCenterY; s = 1; opacity = 1 }
    ParallelAnimation {
      id: dropAnim
      property real fromX: 0
      NumberAnimation { target: f; property: "cx"; from: dropAnim.fromX; to: stage.width / 2; duration: 320; easing.type: Easing.OutCubic }
      NumberAnimation { target: f; property: "cy"; from: stage.tickerMid; to: stage.bigCenterY; duration: 320; easing.type: Easing.OutCubic }
      NumberAnimation { target: f; property: "s"; from: stage.tickerSize / stage.bigSize; to: 1; duration: 320; easing.type: Easing.OutCubic }
      NumberAnimation { target: f; property: "opacity"; from: 0.6; to: 1; duration: 160 }
    }
    ParallelAnimation {
      id: riseAnim
      property real toX: 0
      NumberAnimation { target: f; property: "cx"; to: riseAnim.toX; duration: 340; easing.type: Easing.InOutQuad }
      NumberAnimation { target: f; property: "cy"; to: stage.tickerMid; duration: 340; easing.type: Easing.InOutQuad }
      NumberAnimation { target: f; property: "s"; to: stage.tickerSize / stage.bigSize; duration: 340; easing.type: Easing.InOutQuad }
      // fades early so it doesn't tangle with the word dropping in
      NumberAnimation { target: f; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutQuad }
    }
  }
  Flyer { id: flyA }
  Flyer { id: flyB }

  onCurrentChanged: Qt.callLater(stage.step)
  function step() {
    var c = current, p = lastWord
    lastWord = c
    var a = useA ? flyA : flyB, b = useA ? flyB : flyA
    if (c < 0 || !words.length) { flyA.hide(); flyB.hide(); return }
    // a seek or a new song: no flying, just show it
    if (p < 0 || c < p || c - p > 3) {
      jumped = true
      b.hide(); a.show(words[c].text)
      useA = !useA
      Qt.callLater(function() { stage.jumped = false })
      return
    }
    // the word that was big floats back up to its spot (left of center now)
    b.rise(slotX(p, c))
    // the new word drops from its spot in the strip (it was right of center)
    a.drop(words[c].text, slotX(c, p))
    useA = !useA
  }
  onWordsChanged: { lastWord = -1; flyA.hide(); flyB.hide() }
}
