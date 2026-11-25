import QtQuick
import "../ui"
import "../lib/Format.js" as Format
import "../lib/Glyphs.js" as Glyphs

// Opened while recording the screen: the recording with its Stop button on
// top, and, if music plays too, a small player underneath, so neither is
// hidden behind the other.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var media: island.media
  readonly property int pad: look.s(18)

  Item {
    id: recordingRow
    x: view.pad
    y: view.pad
    width: parent.width - view.pad * 2
    height: view.look.s(40)

    Beacon {
      id: dot
      anchors.left: parent.left
      anchors.leftMargin: view.look.s(4)
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      size: view.look.s(12)
      color: view.look.urgent
    }

    Headline {
      anchors.left: dot.right
      anchors.leftMargin: view.look.s(12)
      anchors.right: stop.left
      anchors.rightMargin: view.look.s(10)
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      spacing: view.look.s(1)
      title: "Screen Recording"
      detail: Format.clock(view.island.recorder.elapsed)
      detailColor: view.look.urgent
    }

    Chip {
      id: stop
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      height: view.look.s(32)
      solid: true
      tone: view.look.urgent
      textSize: 13
      text: Glyphs.STOP + "  Stop"
      onClicked: view.island.recorder.stop()
    }
  }

  Rectangle {
    id: divider
    visible: view.media.present
    x: view.pad
    y: recordingRow.y + recordingRow.height + view.look.s(12)
    width: parent.width - view.pad * 2
    height: 1
    color: view.look.fgFaint
  }

  Item {
    visible: view.media.present
    x: view.pad
    y: divider.y + divider.height + view.look.s(12)
    width: parent.width - view.pad * 2
    height: view.look.s(44)

    // The cover and the song open the app that is playing.
    MouseArea {
      anchors.left: parent.left
      anchors.right: transport.left
      height: parent.height
      enabled: view.media.canShow
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        view.media.showWindow()
        view.island.stage.collapse()
      }
    }

    Cover {
      id: art
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(44)
      height: width
      look: view.look
      sources: view.media.coverSources
    }

    Row {
      id: transport
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: view.look.s(2)

      RoundButton {
        look: view.look
        glyph: Glyphs.PREVIOUS
        glyphSize: 17
        available: view.media.canPrevious
        onClicked: view.media.previous()
      }

      RoundButton {
        look: view.look
        glyph: view.media.playing ? Glyphs.PAUSE : Glyphs.PLAY
        glyphSize: 21
        onClicked: view.media.toggle()
      }

      RoundButton {
        look: view.look
        glyph: Glyphs.NEXT
        glyphSize: 17
        available: view.media.canNext
        onClicked: view.media.next()
      }
    }

    Headline {
      anchors.left: art.right
      anchors.leftMargin: view.look.s(12)
      anchors.right: transport.left
      anchors.rightMargin: view.look.s(8)
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      titleSize: 13
      detailSize: 11
      title: view.media.title
      detail: view.media.artist
    }
  }
}
