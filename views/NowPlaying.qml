import QtQuick
import "../ui"

// Music, compact: the cover leading, the equaliser trailing, and the song
// in between (scrolling when it is too long to fit).
Compact {
  id: view

  property var island: null
  readonly property var media: island.media
  look: island.look
  leadInset: 6
  trailInset: 13
  gap: 9

  lead: Cover {
    look: view.look
    width: view.look.s(22)
    height: width
    source: view.media.cover
  }

  trail: Bars {
    look: view.look
    playing: view.media.playing
    color: view.media.tint
    barWidth: view.look.s(3)
    maxHeight: view.look.s(15)
  }

  middle: Ticker {
    look: view.look
    height: view.look.s(20)
    text: view.media.artist !== "" ? view.media.title + "  ·  " + view.media.artist : view.media.title
    color: view.media.playing ? view.look.fg : view.look.fgDim
    moving: view.media.playing
    speed: view.look.s(30)
    gap: view.look.s(40)
    fadeWidth: view.look.s(12)
    fadeTop: view.look.bodyAt(0.25)
    fadeBottom: view.look.bodyAt(0.75)
  }
}
