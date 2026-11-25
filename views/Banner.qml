import QtQuick
import qs.Commons
import "../ui"
import "../lib/Format.js" as Format
import "../lib/Glyphs.js" as Glyphs

// A notification, iOS-banner style: the app's icon, its name, the summary
// and body, and the sender's actions along the bottom when it has any.
// A click opens it (its default action, or its app); a right or middle
// click, or the ✕, clears it. Hovering holds it on screen.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var notices: island.notices
  readonly property var entry: notices.current
  // While the sender still holds it, read its live text so updates show.
  readonly property var live: entry && entry.live ? entry.live : null
  readonly property string summary: live ? Format.clip(Format.plain(live.summary), 300) : (entry ? entry.summary : "")
  readonly property string body: live ? Format.clip(Format.plain(live.body), 1000) : (entry ? entry.body : "")
  readonly property var actions: entry ? entry.actions : []
  readonly property color tone: entry && entry.critical ? look.urgent : look.accent
  readonly property int pad: look.s(16)

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (!view.entry) return
      if (mouse.button === Qt.LeftButton) view.notices.open(view.entry.key)
      else view.notices.dismiss(view.entry.key)
    }
  }

  Cover {
    id: icon
    x: view.pad
    y: view.look.s(16)
    width: view.look.s(46)
    height: width
    radius: Math.round(width * 0.28)
    look: view.look
    sources: view.notices.iconsFor(view.entry)
    placeholder: view.entry && view.entry.glyph ? view.entry.glyph : Glyphs.BELL
    tint: view.tone
  }

  Column {
    anchors.left: icon.right
    anchors.leftMargin: view.look.s(12)
    anchors.right: parent.right
    anchors.rightMargin: view.pad + view.look.s(4)
    y: icon.y - view.look.s(1)
    spacing: view.look.s(2)

    Item {
      width: parent.width
      height: app.implicitHeight

      Label {
        id: app
        anchors.left: parent.left
        anchors.right: more.visible ? more.left : closer.left
        anchors.rightMargin: view.look.s(6)
        look: view.look
        size: 11
        text: view.entry ? (view.entry.app || "Notification") : ""
        color: view.entry && view.entry.critical ? view.look.urgent : view.look.fgDim
      }

      // More waiting behind this one.
      Rectangle {
        id: more
        visible: view.notices.waiting > 0
        anchors.right: closer.left
        anchors.rightMargin: view.look.s(6)
        anchors.verticalCenter: parent.verticalCenter
        height: moreText.implicitHeight + view.look.s(2)
        width: moreText.implicitWidth + view.look.s(12)
        radius: height / 2
        color: Util.alpha(view.tone, 0.22)

        Label {
          id: moreText
          anchors.centerIn: parent
          look: view.look
          size: 10
          weight: Font.DemiBold
          text: "+" + view.notices.waiting
          color: view.tone
        }
      }

      RoundButton {
        id: closer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: view.look.s(20)
        height: width
        look: view.look
        glyph: Glyphs.CLOSE
        glyphSize: 10
        backed: true
        onClicked: if (view.entry) view.notices.dismiss(view.entry.key)
      }
    }

    Label {
      width: parent.width
      look: view.look
      size: 13
      weight: Font.DemiBold
      text: view.summary
    }

    Label {
      width: parent.width
      visible: text !== ""
      look: view.look
      size: 12
      text: view.body
      color: view.look.fgDim
    }
  }

  Row {
    visible: view.actions.length > 0
    x: view.pad
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.look.s(14)
    width: parent.width - view.pad * 2
    spacing: view.look.s(8)

    Repeater {
      model: view.actions

      Chip {
        required property var modelData
        look: view.look
        height: view.look.s(28)
        fixedWidth: (parent.width - parent.spacing * (view.actions.length - 1)) / view.actions.length
        text: modelData.text
        onClicked: if (view.entry) view.notices.act(view.entry.key, modelData.id)
      }
    }
  }
}
