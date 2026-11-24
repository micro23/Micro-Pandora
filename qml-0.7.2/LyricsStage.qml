import QtQuick
import qs.Commons as Commons

// lrclib times whole lines. Estimate word timing by syllable count.
Item {
  id: stage

  property var timedLines: []              // [{ time, text }] from the service
  property real position: 0           // play position the service reports, seconds
  property bool playing: false
  property bool active: visible
  property color foreground: "white"
  property color accent: "white"
  property color accentAlt: "white"
  property string fontFamily: ""

  implicitHeight: Math.max(Commons.Style.space(34), row.implicitHeight + Commons.Style.space(8))
  height: implicitHeight
  clip: true

  // ── Words with estimated times ────────────────
  // Rough syllable count: groups of vowels (a trailing silent e doesn't count).
  function syllables(word) {
    var w = String(word).toLowerCase().replace(/[^a-z]/g, "")
    if (!w) return 1
    var n = (w.replace(/e$/, "").match(/[aeiouy]+/g) || []).length
    return Math.max(1, n)
  }
  property var words: []
  onTimedLinesChanged: rebuildWords()

  function rebuildWords() {
    var entries = timedLines || []
    var out = []
    for (var i = 0; i < entries.length; i++) {
      var t = entries[i].time
      var end = i + 1 < entries.length ? entries[i + 1].time : t + 4
      var parts = String(entries[i].text || "").split(/\s+/).filter(function(w) { return w !== "" })
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
    words = out
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
    interval: 20
    repeat: true
    running: stage.active && stage.playing && stage.words.length > 0
    onTriggered: stage.smooth = stage.base + (Date.now() - stage.stamp) / 1000
  }

  readonly property int current: {
    var i = -1
    for (var k = 0; k < words.length; k++) {
      if (words[k].time <= smooth + 0.35) i = k
      else break
    }
    return i
  }

  function slotCenter(i) {
    var item = strip.itemAt(i)
    return item ? item.x + item.width / 2 : 0
  }

  Row {
    id: row
    spacing: Commons.Style.space(14)
    height: parent.height
    x: stage.width / 2 - stage.slotCenter(Math.max(0, stage.current))

    Behavior on x {
      NumberAnimation { duration: Commons.Style.duration(180); easing.type: Easing.OutCubic }
    }

    Repeater {
      id: strip
      model: stage.words

      Text {
        objectName: "lyricWord"
        required property var modelData
        required property int index
        readonly property bool singing: index === stage.current
        readonly property int distance: Math.abs(index - stage.current)

        anchors.verticalCenter: parent.verticalCenter
        text: modelData.text
        textFormat: Text.PlainText
        color: singing ? stage.accent : (index > stage.current ? stage.accentAlt : stage.foreground)
        opacity: singing ? 1 : Math.max(0.22, (index < stage.current ? 0.52 : 0.78) - distance * 0.04)
        font.family: stage.fontFamily
        font.pixelSize: Commons.Style.space(26)
        font.weight: Font.DemiBold

        Behavior on color { ColorAnimation { duration: Commons.Style.duration(140) } }
        Behavior on opacity { NumberAnimation { duration: Commons.Style.duration(140) } }
      }
    }
  }
}
