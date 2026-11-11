import QtQuick
import qs.Commons
import "../ui"
import "../lib/Format.js" as Format
import "../lib/Glyphs.js" as Glyphs
import "../lib/Layout.js" as Layout

// The opened inbox: every notification not acted on yet, newest first. A
// row opens its app, its ✕ clears it, and "Clear all" clears them all.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var notices: island.notices
  readonly property var rows: notices.inbox
  readonly property int pad: look.s(14)
  property double now: Date.now()

  Timer {
    interval: 30000
    repeat: true
    triggeredOnStart: true
    running: view.visible
    onTriggered: view.now = Date.now()
  }

  Label {
    visible: view.rows.length === 0
    anchors.centerIn: parent
    look: view.look
    size: 13
    text: "No notifications"
    color: view.look.fgDim
  }

  ListView {
    visible: view.rows.length > 0
    x: view.pad
    y: view.pad
    width: parent.width - view.pad * 2
    height: clearAll.y - view.look.s(10) - y
    clip: true
    spacing: view.look.s(Layout.INBOX_GAP)
    boundsBehavior: Flickable.StopAtBounds
    model: view.rows

    delegate: Rectangle {
      id: row
      required property var modelData
      width: ListView.view.width
      height: view.look.s(Layout.INBOX_ROW)
      radius: view.look.s(18)
      color: Util.alpha(view.look.fg, rowMouse.containsMouse ? 0.1 : 0.05)

      Behavior on color { ColorAnimation { duration: view.look.ms(120) } }

      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.notices.open(row.modelData.key)
      }

      Cover {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: view.look.s(10)
        anchors.verticalCenter: parent.verticalCenter
        width: view.look.s(36)
        height: width
        radius: Math.round(width * 0.28)
        look: view.look
        source: view.notices.iconFor(row.modelData)
        placeholder: row.modelData.glyph ? row.modelData.glyph : Glyphs.BELL
        tint: row.modelData.critical ? view.look.urgent : view.look.accent
      }

      RoundButton {
        id: closer
        anchors.right: parent.right
        anchors.rightMargin: view.look.s(10)
        anchors.verticalCenter: parent.verticalCenter
        width: view.look.s(24)
        height: width
        look: view.look
        glyph: Glyphs.CLOSE
        glyphSize: 12
        backed: true
        onClicked: view.notices.dismiss(row.modelData.key)
      }

      Column {
        anchors.left: icon.right
        anchors.leftMargin: view.look.s(10)
        anchors.right: closer.left
        anchors.rightMargin: view.look.s(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: view.look.s(1)

        Label {
          width: parent.width
          look: view.look
          size: 10
          text: (row.modelData.app || "Notification") + "  ·  " + Format.ago(row.modelData.time, view.now)
          color: row.modelData.critical ? view.look.urgent : view.look.fgDim
        }

        Label {
          width: parent.width
          look: view.look
          size: 12
          weight: Font.DemiBold
          text: row.modelData.summary
        }

        Label {
          width: parent.width
          visible: text !== ""
          look: view.look
          size: 11
          text: row.modelData.body
          color: view.look.fgDim
        }
      }
    }
  }

  Chip {
    id: clearAll
    visible: view.rows.length > 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.pad
    look: view.look
    text: Glyphs.CLOSE + "  Clear all"
    onClicked: {
      view.notices.clearAll()
      view.island.stage.done()
    }
  }
}
