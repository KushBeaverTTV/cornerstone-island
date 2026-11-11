import QtQuick
import qs.Commons
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// Notifications waiting: a bell leading and how many trailing.
Compact {
  id: view

  property var island: null
  look: island.look
  leadInset: 13
  trailInset: 9

  lead: Label {
    look: view.look
    mono: true
    size: 15
    text: Glyphs.BELL
    color: view.look.accent
  }

  trail: Rectangle {
    height: view.look.s(18)
    width: Math.max(height, count.implicitWidth + view.look.s(12))
    radius: height / 2
    color: Util.alpha(view.look.accent, 0.22)

    Label {
      id: count
      anchors.centerIn: parent
      look: view.look
      size: 11
      weight: Font.DemiBold
      text: String(view.island.notices.inbox.length)
      color: view.look.accent
    }
  }
}
