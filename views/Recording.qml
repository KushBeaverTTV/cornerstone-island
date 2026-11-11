import QtQuick
import "../ui"
import "../lib/Format.js" as Format

// Screen recording, compact: a breathing dot with REC, and the time.
Compact {
  id: view

  property var island: null
  look: island.look
  leadInset: 12
  trailInset: 13

  lead: Row {
    spacing: view.look.s(7)

    Beacon {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      size: view.look.s(10)
      color: view.look.urgent
    }

    Label {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      size: 11
      weight: Font.DemiBold
      font.letterSpacing: 0.6
      text: "REC"
      color: view.look.urgent
    }
  }

  trail: Label {
    look: view.look
    mono: true
    size: 13
    weight: Font.Bold
    text: Format.clock(view.island.recorder.elapsed)
    color: view.look.urgent
  }
}
