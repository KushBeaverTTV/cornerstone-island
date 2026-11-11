import QtQuick
import qs.Commons

// The island's status light: a thin line along its lower lip whose colour,
// brightness and shape say what the island is doing:
//   glow      a soft line, bright in the middle (resting, playing, recording)
//   progress  a fill from the left (a timer, a level, a script's progress)
//   sweep     a bead of light running across once (something arrived)
// Vector rectangles and gradients only, so it stays crisp.
Item {
  id: lip

  property var look: null
  property color tone: "white"
  property real level: 0.3             // brightness, 0..1
  property real progress: -1           // 0..1, or below 0 for a glow
  property bool pulse: false           // breathe (playing, recording)
  property int period: 1400
  property int sweeps: 0               // bump to run one sweep

  property real breath: 1
  readonly property real shown: level * (pulse ? breath : 1)

  SequentialAnimation on breath {
    running: lip.pulse && lip.visible && !lip.look.still
    loops: Animation.Infinite
    NumberAnimation { to: 0.45; duration: lip.period / 2; easing.type: Easing.InOutSine }
    NumberAnimation { to: 1; duration: lip.period / 2; easing.type: Easing.InOutSine }
    onRunningChanged: if (!running) lip.breath = 1
  }

  Behavior on level { NumberAnimation { duration: lip.look.ms(240); easing.type: Easing.OutCubic } }
  Behavior on tone { ColorAnimation { duration: lip.look.ms(240) } }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    visible: lip.progress < 0
    opacity: lip.shown
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Util.alpha(lip.tone, 0) }
      GradientStop { position: 0.3; color: Util.alpha(lip.tone, 0.85) }
      GradientStop { position: 0.5; color: lip.tone }
      GradientStop { position: 0.7; color: Util.alpha(lip.tone, 0.85) }
      GradientStop { position: 1.0; color: Util.alpha(lip.tone, 0) }
    }
  }

  Item {
    anchors.fill: parent
    visible: lip.progress >= 0

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Util.alpha(lip.tone, 0.14 * lip.level)
    }

    Rectangle {
      height: parent.height
      radius: height / 2
      width: parent.width * Math.min(1, Math.max(0, lip.progress))
      opacity: lip.shown
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Util.alpha(lip.tone, 0.35) }
        GradientStop { position: 1.0; color: lip.tone }
      }
      Behavior on width { NumberAnimation { duration: lip.look.ms(240); easing.type: Easing.OutCubic } }
    }
  }

  Rectangle {
    id: bead
    height: parent.height
    width: parent.width * 0.32
    radius: height / 2
    x: -width
    opacity: 0
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Util.alpha(lip.tone, 0) }
      GradientStop { position: 0.6; color: Qt.lighter(lip.tone, 1.25) }
      GradientStop { position: 1.0; color: Util.alpha(lip.tone, 0) }
    }
  }

  onSweepsChanged: if (!look.still) sweep.restart()

  SequentialAnimation {
    id: sweep
    PropertyAction { target: bead; property: "x"; value: -bead.width }
    PropertyAction { target: bead; property: "opacity"; value: 1 }
    NumberAnimation { target: bead; property: "x"; to: lip.width; duration: lip.look.ms(280); easing.type: Easing.OutCubic }
    PropertyAction { target: bead; property: "opacity"; value: 0 }
  }
}
