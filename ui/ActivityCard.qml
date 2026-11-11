import QtQuick
import "../lib/Glyphs.js" as Glyphs

// An opened live activity: its badge, the title with a value beside it, a
// second line, a progress bar when there is progress, and a ✕.
Item {
  id: card

  property var look: null
  property string glyph: ""
  property color tone: look ? look.accent : "white"
  property real progress: -1
  property string title: ""
  property string value: ""
  property string detail: ""
  // The badge breathes while something is happening with no set length.
  property bool breathing: false

  signal close()

  readonly property int pad: look.s(20)

  Badge {
    id: badge
    x: card.pad
    anchors.verticalCenter: parent.verticalCenter
    width: card.look.s(48)
    height: width
    look: card.look
    glyph: card.glyph
    tone: card.tone
    progress: card.progress
    ringWidth: card.look.s(3)

    SequentialAnimation on opacity {
      running: card.breathing && card.visible && !card.look.still
      loops: Animation.Infinite
      NumberAnimation { to: 0.55; duration: 800; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
      onRunningChanged: if (!running) badge.opacity = 1
    }
  }

  RoundButton {
    id: closer
    anchors.right: parent.right
    anchors.rightMargin: card.pad - card.look.s(6)
    anchors.verticalCenter: parent.verticalCenter
    look: card.look
    glyph: Glyphs.CLOSE
    glyphSize: 16
    onClicked: card.close()
  }

  Column {
    anchors.left: badge.right
    anchors.leftMargin: card.look.s(14)
    anchors.right: closer.left
    anchors.rightMargin: card.look.s(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: card.look.s(3)

    Item {
      width: parent.width
      height: title.implicitHeight

      Label {
        id: title
        anchors.left: parent.left
        anchors.right: value.left
        anchors.rightMargin: card.look.s(8)
        look: card.look
        size: 14
        weight: Font.DemiBold
        text: card.title
      }

      Label {
        id: value
        anchors.right: parent.right
        anchors.verticalCenter: title.verticalCenter
        look: card.look
        mono: true
        size: 12
        weight: Font.Bold
        text: card.value
        color: card.tone
      }
    }

    Label {
      width: parent.width
      visible: text !== ""
      look: card.look
      size: 12
      text: card.detail
      color: card.look.fgDim
    }

    Meter {
      visible: card.progress >= 0
      width: parent.width
      height: card.look.s(6)
      look: card.look
      thickness: card.look.s(4)
      value: card.progress
      color: card.tone
    }
  }
}
