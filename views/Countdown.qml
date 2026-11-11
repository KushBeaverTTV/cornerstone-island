import QtQuick
import "../ui"
import "../lib/Format.js" as Format
import "../lib/Glyphs.js" as Glyphs

// The timer or the stopwatch, compact. The timer's glyph sits in a ring
// that fills as its time runs out; the time hugs the trailing edge.
Compact {
  id: view

  property var island: null
  property bool stopwatch: false
  readonly property var clocks: island.clocks
  readonly property bool paused: stopwatch ? !clocks.stopwatchRunning : clocks.timerPaused
  readonly property color tone: paused ? look.fgDim : (stopwatch ? look.accent : look.orange)
  look: island.look
  leadInset: 6
  trailInset: 14

  lead: Badge {
    look: view.look
    width: view.look.s(22)
    height: width
    filled: false
    progress: view.stopwatch ? -1 : view.clocks.timerProgress
    ringWidth: view.look.s(2)
    glyph: view.stopwatch ? Glyphs.STOPWATCH : (view.paused ? Glyphs.PAUSE : Glyphs.TIMER)
    glyphSize: view.stopwatch ? 15 : 11
    tone: view.tone
  }

  trail: Label {
    look: view.look
    mono: true
    size: 13
    weight: Font.Bold
    text: view.stopwatch ? Format.clock(view.clocks.stopwatchElapsed / 1000) : Format.clock(Math.ceil(view.clocks.timerLeft / 1000))
    color: view.tone
  }
}
