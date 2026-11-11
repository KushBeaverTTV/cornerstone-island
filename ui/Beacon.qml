import QtQuick

// A dot that breathes: recording, listening, privacy. Breathing is constant
// motion, so it stops when the shell's animations are off.
Rectangle {
  id: beacon

  property var look: null
  property real size: 10
  property bool breathing: true
  property int period: 1600

  width: size
  height: size
  radius: size / 2

  SequentialAnimation on opacity {
    running: beacon.breathing && beacon.visible && !(beacon.look && beacon.look.still)
    loops: Animation.Infinite
    NumberAnimation { to: 0.35; duration: beacon.period / 2; easing.type: Easing.InOutSine }
    NumberAnimation { to: 1; duration: beacon.period / 2; easing.type: Easing.InOutSine }
    onRunningChanged: if (!running) beacon.opacity = 1
  }
}
