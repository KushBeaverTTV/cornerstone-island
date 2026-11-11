import QtQuick
import "../ui"

// A level HUD (volume, brightness, an OSD value): glyph, bar, percentage.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var hud: island.hud.current || ({})
  readonly property color tone: look.tone(hud.tone || "fg")

  Label {
    id: glyph
    anchors.left: parent.left
    anchors.leftMargin: view.look.s(14)
    anchors.verticalCenter: parent.verticalCenter
    width: view.look.s(20)
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideNone
    look: view.look
    mono: true
    size: 16
    text: view.hud.icon || ""
  }

  Label {
    id: readout
    anchors.right: parent.right
    anchors.rightMargin: view.look.s(15)
    anchors.verticalCenter: parent.verticalCenter
    width: view.look.s(42)
    horizontalAlignment: Text.AlignRight
    look: view.look
    mono: true
    size: 12
    weight: Font.Bold
    text: view.hud.valueText || ""
  }

  Meter {
    anchors.left: glyph.right
    anchors.leftMargin: view.look.s(12)
    anchors.right: readout.left
    anchors.rightMargin: view.look.s(10)
    anchors.verticalCenter: parent.verticalCenter
    look: view.look
    thickness: view.look.s(5)
    value: Number(view.hud.value) || 0
    color: view.tone
  }
}
