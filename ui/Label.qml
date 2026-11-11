import QtQuick

// All text in the island goes through this. It is always plain text: titles,
// bodies, app and device names come from other programs and must never be
// read as markup (markup-shaped text could load images or links).
Text {
  id: label

  property var look: null
  // Theme monospace (numbers, times, glyphs) or the text font (words).
  property bool mono: false
  // Unscaled size; the island's scale and the shell's font scale apply.
  property real size: 12
  property int weight: Font.Normal

  textFormat: Text.PlainText
  renderType: Text.NativeRendering
  elide: Text.ElideRight
  maximumLineCount: 1
  font.family: look ? (mono ? look.mono : look.sans) : ""
  font.pixelSize: look ? look.f(size) : size
  font.weight: weight
  // Figures that do not jiggle as they change.
  font.features: mono ? { "tnum": 1 } : ({})
  color: look ? look.fg : "white"
}
