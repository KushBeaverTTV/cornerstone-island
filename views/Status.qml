import QtQuick
import "../ui"

// A status HUD in the iOS "Charging ····· 80% ▮" shape: the words leading,
// the value and its glyph trailing in the event's colour.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var hud: island.hud.current || ({})
  readonly property color tone: look.tone(hud.tone || "fg")

  Label {
    anchors.left: parent.left
    anchors.leftMargin: view.look.s(16)
    anchors.right: trailing.left
    anchors.rightMargin: view.look.s(10)
    anchors.verticalCenter: parent.verticalCenter
    look: view.look
    size: 13
    weight: Font.DemiBold
    text: view.hud.label || ""
  }

  Row {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: view.look.s(14)
    anchors.verticalCenter: parent.verticalCenter
    spacing: view.look.s(6)

    Label {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      mono: true
      size: 13
      weight: Font.Bold
      text: view.hud.valueText || ""
      color: view.tone
    }

    Label {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      mono: true
      size: 18
      text: view.hud.icon || ""
      color: view.tone
    }
  }
}
