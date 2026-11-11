import QtQuick
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// Cornerstone dictation, compact: a red microphone and the running time
// while listening; the accent colour and a breathing dot while transcribing.
Compact {
  id: view

  property var island: null
  readonly property var dictation: island.dictation
  readonly property color tone: dictation.listening ? look.urgent : look.accent
  look: island.look
  leadInset: 13
  trailInset: 14

  lead: Label {
    look: view.look
    mono: true
    size: 15
    text: Glyphs.MIC
    color: view.tone
  }

  middle: Label {
    look: view.look
    size: 12
    weight: Font.DemiBold
    text: view.dictation.listening ? "Listening" : "Transcribing"
    color: view.look.fg
  }

  trail: Item {
    width: Math.max(time.implicitWidth, dot.width)
    height: time.implicitHeight

    Label {
      id: time
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: view.dictation.listening
      look: view.look
      mono: true
      size: 13
      weight: Font.Bold
      text: view.dictation.elapsed
      color: view.tone
    }

    Beacon {
      id: dot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: !view.dictation.listening
      look: view.look
      size: view.look.s(8)
      period: 1000
      color: view.tone
    }
  }
}
