import QtQuick

// Text that turns over to its next value like a split-flap board: the old
// value lifts out and the new one rises in a beat behind it, so the two
// never smear together. Sized to the island, it clips to itself.
Item {
  id: flip

  property var look: null
  property string text: ""
  property color color: "white"
  property real size: 12

  readonly property real restY: Math.round((height - shown.implicitHeight) / 2)
  readonly property int outMs: look ? look.ms(140) : 140
  readonly property int inMs: look ? look.ms(220) : 220

  clip: true
  implicitWidth: Math.max(shown.implicitWidth, coming.implicitWidth)
  implicitHeight: shown.implicitHeight

  onTextChanged: {
    if (shown.text === "" || outMs === 0) {
      shown.text = text
      shown.color = color
      return
    }
    coming.text = text
    coming.color = color
    turn.restart()
  }
  onColorChanged: if (!turn.running) shown.color = color

  Label {
    id: shown
    anchors.horizontalCenter: parent.horizontalCenter
    y: flip.restY
    look: flip.look
    mono: true
    size: flip.size
    weight: Font.Bold
    elide: Text.ElideNone
  }

  Label {
    id: coming
    anchors.horizontalCenter: parent.horizontalCenter
    y: flip.height
    opacity: 0
    look: flip.look
    mono: true
    size: flip.size
    weight: Font.Bold
    elide: Text.ElideNone
  }

  SequentialAnimation {
    id: turn
    ParallelAnimation {
      NumberAnimation { target: shown; property: "y"; to: flip.restY - flip.height / 2; duration: flip.outMs; easing.type: Easing.OutCubic }
      NumberAnimation { target: shown; property: "opacity"; to: 0; duration: flip.outMs; easing.type: Easing.OutCubic }
      SequentialAnimation {
        PauseAnimation { duration: flip.outMs / 2 }
        ParallelAnimation {
          NumberAnimation { target: coming; property: "y"; from: flip.restY + flip.height / 2; to: flip.restY; duration: flip.inMs; easing.type: Easing.OutCubic }
          NumberAnimation { target: coming; property: "opacity"; from: 0; to: 1; duration: flip.inMs; easing.type: Easing.OutCubic }
        }
      }
    }
    ScriptAction {
      script: {
        shown.text = coming.text
        shown.color = coming.color
        shown.y = Qt.binding(function() { return flip.restY })
        shown.opacity = 1
        coming.opacity = 0
      }
    }
  }
}
