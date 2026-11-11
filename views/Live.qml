import QtQuick
import "../ui"

// A script's live activity, compact: its glyph leading (in a ring when it
// reports progress), and its value or percentage trailing.
Compact {
  id: view

  property var island: null
  readonly property var item: island.activities.current
  readonly property color tone: look.tone(item ? item.color : "")
  readonly property bool measured: !!item && item.progress >= 0
  look: island.look
  leadInset: 6
  trailInset: 14

  lead: Badge {
    look: view.look
    width: view.look.s(22)
    height: width
    filled: false
    progress: view.measured ? view.item.progress : -1
    ringWidth: view.look.s(2)
    glyph: view.item ? view.item.icon : ""
    glyphSize: view.measured ? 10 : 15
    tone: view.tone
  }

  trail: Label {
    look: view.look
    mono: true
    size: 12
    weight: Font.Bold
    text: !view.item ? "" : (view.item.value !== "" ? view.item.value : (view.measured ? Math.round(view.item.progress * 100) + "%" : ""))
    color: view.tone
  }
}
