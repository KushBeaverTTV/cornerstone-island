import QtQuick
import qs.Commons

// A glyph in a tinted circle, with an optional progress ring around it: the
// face of timers, script activities, toasts and dictation.
Item {
  id: badge

  property var look: null
  property string glyph: ""
  property color tone: look ? look.accent : "white"
  // 0..1 for a ring, or below 0 for none.
  property real progress: -1
  // Without a backdrop it is just the glyph (and ring), for compact rows.
  property bool filled: true
  property real glyphSize: 18
  property real ringWidth: 2

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    visible: badge.filled
    color: Util.alpha(badge.tone, 0.2)
  }

  Ring {
    anchors.fill: parent
    anchors.margins: badge.filled ? badge.ringWidth * 1.5 : 0
    visible: badge.progress >= 0
    look: badge.look
    progress: Math.max(0, badge.progress)
    color: badge.tone
    lineWidth: badge.ringWidth
  }

  Label {
    anchors.centerIn: parent
    look: badge.look
    mono: true
    size: badge.glyphSize
    text: badge.glyph
    color: badge.tone
    elide: Text.ElideNone
  }
}
