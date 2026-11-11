import QtQuick
import "../ui"

// A message: from a script over IPC (build finished, agent done), a timer
// ringing, a meeting starting, a dictation result.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var hud: island.hud.current || ({})
  readonly property color tone: look.tone(hud.tone)

  Badge {
    id: badge
    anchors.left: parent.left
    anchors.leftMargin: view.look.s(11)
    anchors.verticalCenter: parent.verticalCenter
    width: view.look.s(44)
    height: width
    look: view.look
    glyph: view.hud.icon || "\u{f009a}"
    glyphSize: 20
    tone: view.tone
  }

  Headline {
    anchors.left: badge.right
    anchors.leftMargin: view.look.s(12)
    anchors.right: parent.right
    anchors.rightMargin: view.look.s(22)
    anchors.verticalCenter: parent.verticalCenter
    look: view.look
    title: view.hud.title || ""
    detail: view.hud.body || ""
  }
}
