import QtQuick
import qs.Commons
import "../ui"
import "../lib/Glyphs.js" as Glyphs
import "../lib/Layout.js" as Layout

// "Play on": every audio output PipeWire knows (speakers, headphones,
// Bluetooth, HDMI). A row moves the sound there.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var sound: island.sound
  readonly property int pad: look.s(16)

  Row {
    id: header
    x: view.pad
    y: view.pad
    height: view.look.s(22)
    spacing: view.look.s(6)

    RoundButton {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      glyph: Glyphs.BACK
      glyphSize: 13
      onClicked: view.island.stage.closeOutputs()
    }

    Label {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      size: 13
      weight: Font.DemiBold
      text: "Play on"
    }
  }

  Column {
    x: view.pad
    y: header.y + header.height + view.look.s(8)
    width: parent.width - view.pad * 2
    spacing: view.look.s(Layout.OUTPUT_GAP)

    Repeater {
      model: view.sound.outputs.slice(0, 6)

      Rectangle {
        id: row
        required property var modelData
        readonly property bool current: view.sound.isCurrent(modelData)
        width: parent.width
        height: view.look.s(Layout.OUTPUT_ROW)
        radius: view.look.s(14)
        color: current ? Util.alpha(view.look.accent, 0.18) : Util.alpha(view.look.fg, rowMouse.containsMouse ? 0.1 : 0.04)

        Behavior on color { ColorAnimation { duration: view.look.ms(120) } }

        Label {
          id: glyph
          anchors.left: parent.left
          anchors.leftMargin: view.look.s(12)
          anchors.verticalCenter: parent.verticalCenter
          look: view.look
          mono: true
          size: 16
          text: view.sound.glyph(row.modelData)
          color: row.current ? view.look.accent : view.look.fg
        }

        Label {
          anchors.left: glyph.right
          anchors.leftMargin: view.look.s(12)
          anchors.right: check.left
          anchors.rightMargin: view.look.s(8)
          anchors.verticalCenter: parent.verticalCenter
          look: view.look
          size: 12
          weight: row.current ? Font.Bold : Font.Normal
          text: view.sound.label(row.modelData)
        }

        Label {
          id: check
          anchors.right: parent.right
          anchors.rightMargin: view.look.s(14)
          anchors.verticalCenter: parent.verticalCenter
          visible: row.current
          look: view.look
          mono: true
          size: 14
          text: Glyphs.CHECK
          color: view.look.accent
        }

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.sound.choose(row.modelData)
        }
      }
    }
  }
}
