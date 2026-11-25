import QtQuick
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// The detached circle that carries the second live activity while the pill
// is busy with the first, like iOS's split island.
Item {
  id: face

  property var island: null
  property string kind: ""
  readonly property var look: island.look
  readonly property var item: island.activities.current

  Cover {
    anchors.centerIn: parent
    visible: face.kind === "media"
    width: parent.width - face.look.s(10)
    height: width
    radius: width / 2
    look: face.look
    sources: face.island.media.coverSources
  }

  Beacon {
    anchors.centerIn: parent
    visible: face.kind === "recording"
    look: face.look
    size: face.look.s(11)
    color: face.look.urgent
  }

  Badge {
    anchors.fill: parent
    anchors.margins: face.look.s(5)
    visible: ["timer", "stopwatch", "activity", "calendar", "inbox", "mic", "dictation"].indexOf(face.kind) !== -1
    look: face.look
    filled: false
    ringWidth: face.look.s(2)
    progress: face.kind === "timer" ? face.island.clocks.timerProgress
      : (face.kind === "activity" && face.item ? face.item.progress : -1)
    glyphSize: progress >= 0 ? 11 : 15
    glyph: {
      switch (face.kind) {
      case "timer": return Glyphs.TIMER
      case "stopwatch": return Glyphs.STOPWATCH
      case "calendar": return Glyphs.CALENDAR
      case "inbox": return Glyphs.BELL
      case "dictation": return Glyphs.MIC
      case "mic": return face.island.privacy.cameraInUse ? Glyphs.CAMERA : Glyphs.MIC
      case "activity": return face.item ? face.item.icon : ""
      }
      return ""
    }
    tone: {
      switch (face.kind) {
      case "timer": return face.look.orange
      case "dictation": return face.island.dictation.listening ? face.look.urgent : face.look.accent
      case "mic": return face.island.privacy.cameraInUse ? face.look.green : face.look.orange
      case "activity": return face.look.tone(face.item ? face.item.color : "")
      }
      return face.look.accent
    }
  }
}
