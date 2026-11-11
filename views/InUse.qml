import QtQuick
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// The microphone or camera is in use: its glyph leading and a still dot
// trailing, orange for the microphone and green for the camera, like iOS.
Compact {
  id: view

  property var island: null
  readonly property bool camera: island.privacy.cameraInUse
  readonly property color tone: camera ? look.green : look.orange
  look: island.look
  leadInset: 13
  trailInset: 14

  lead: Label {
    look: view.look
    mono: true
    size: 15
    text: view.camera ? Glyphs.CAMERA : Glyphs.MIC
    color: view.tone
  }

  trail: Beacon {
    look: view.look
    size: view.look.s(8)
    breathing: false
    color: view.tone
  }
}
