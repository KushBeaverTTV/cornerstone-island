import QtQuick
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// The next meeting, compact: a calendar glyph, the title, and how long
// until it starts. Red once it has started.
Compact {
  id: view

  property var island: null
  readonly property var calendar: island.calendar
  readonly property color tone: calendar.started ? look.urgent : look.accent
  look: island.look
  leadInset: 13
  trailInset: 14

  lead: Label {
    look: view.look
    mono: true
    size: 15
    text: Glyphs.CALENDAR
    color: view.tone
  }

  trail: Label {
    look: view.look
    size: 12
    weight: Font.DemiBold
    text: view.calendar.countdown
    color: view.tone
  }

  middle: Ticker {
    look: view.look
    height: view.look.s(20)
    text: view.calendar.next ? view.calendar.next.title : ""
    color: view.look.fg
    speed: view.look.s(26)
    gap: view.look.s(40)
    fadeWidth: view.look.s(10)
    fadeTop: view.look.bodyAt(0.25)
    fadeBottom: view.look.bodyAt(0.75)
  }
}
