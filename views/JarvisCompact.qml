import QtQuick
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// Cornerstone Jarvis, compact pill: live voice capture, transcription,
// streaming agent progress, or spoken reply right in the Dynamic Island.
Compact {
  id: view

  property var island: null
  readonly property var jarvis: island.jarvis
  readonly property color tone: jarvis.listening ? look.urgent
    : (jarvis.speaking ? look.green : look.accent)
  look: island.look
  leadInset: 13
  trailInset: 14

  lead: Label {
    look: view.look
    mono: true
    size: 15
    text: view.jarvis.listening ? Glyphs.MIC : (view.jarvis.speaking ? Glyphs.SPEAKER : Glyphs.SPARKLE)
    color: view.tone
  }

  middle: Label {
    look: view.look
    size: 12
    weight: Font.DemiBold
    text: {
      if (view.jarvis.listening) return "Listening"
      if (view.jarvis.transcribing) return "Transcribing…"
      if (view.jarvis.speaking) return "Jarvis speaking"
      if (view.jarvis.statusLine !== "") return view.jarvis.statusLine
      return "Jarvis thinking…"
    }
    color: view.look.fg
  }

  trail: Item {
    width: view.jarvis.listening ? bars.width : Math.max(time.implicitWidth, dot.width)
    height: view.look.s(18)

    Row {
      id: bars
      visible: view.jarvis.listening
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: view.look.s(2)
      Repeater {
        model: [0.55, 1.0, 0.78, 0.45]
        Rectangle {
          required property real modelData
          width: view.look.s(2.5)
          height: view.look.s(4 + Math.min(1, view.jarvis.level * 1.4) * 12 * modelData)
          radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: view.tone
          Behavior on height { NumberAnimation { duration: view.look.ms(110); easing.type: Easing.OutCubic } }
        }
      }
    }

    Label {
      id: time
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: view.jarvis.thinking
      look: view.look
      mono: true
      size: 11
      weight: Font.Bold
      text: view.jarvis.elapsed
      color: view.tone
    }

    Beacon {
      id: dot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: view.jarvis.transcribing || view.jarvis.speaking
      look: view.look
      size: view.look.s(8)
      period: 950
      color: view.tone
    }
  }
}
