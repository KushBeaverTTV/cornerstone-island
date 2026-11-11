import QtQuick
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// Cornerstone dictation, opened. While listening, the ✕ stops listening
// (Cornerstone then transcribes); while transcribing, it puts the activity
// away until the result arrives.
ActivityCard {
  id: view

  property var island: null
  readonly property var dictation: island.dictation
  look: island.look
  glyph: Glyphs.MIC
  tone: dictation.listening ? look.urgent : look.accent
  breathing: true
  title: dictation.listening ? "Listening" : "Transcribing"
  value: dictation.listening ? dictation.elapsed : "working"
  detail: dictation.listening ? "Cornerstone · ✕ stops listening" : "Cornerstone"

  onClose: {
    dictation.stop()
    island.stage.done()
  }
}
