import QtQuick
import "../ui"

// A short now-playing card when the song changes.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var media: island.media

  Cover {
    id: art
    anchors.left: parent.left
    anchors.leftMargin: view.look.s(11)
    anchors.verticalCenter: parent.verticalCenter
    width: view.look.s(44)
    height: width
    look: view.look
    source: view.media.cover
  }

  Bars {
    id: bars
    anchors.right: parent.right
    anchors.rightMargin: view.look.s(20)
    anchors.verticalCenter: parent.verticalCenter
    look: view.look
    playing: view.media.playing
    color: view.media.tint
    barWidth: view.look.s(3)
    maxHeight: view.look.s(18)
  }

  Headline {
    anchors.left: art.right
    anchors.leftMargin: view.look.s(12)
    anchors.right: bars.left
    anchors.rightMargin: view.look.s(14)
    anchors.verticalCenter: parent.verticalCenter
    look: view.look
    title: view.media.title
    detail: view.media.artist
  }
}
