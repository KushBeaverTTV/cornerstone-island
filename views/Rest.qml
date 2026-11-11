import QtQuick
import qs.Commons
import "../ui"

// The resting island ("idleFace"):
//   ticker  a glance that turns over: time, date, battery, next meeting,
//           today's holiday, silenced (default)
//   clock   just the time
//   lens    a camera lens, like the hardware island
//   none    the plain pill
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property string face: island.settings.idleFace
  readonly property var glance: island.glance.current

  FlipLabel {
    anchors.fill: parent
    visible: view.face === "ticker" || view.face === "clock"
    look: view.look
    size: 12
    text: view.glance ? view.glance.text : ""
    color: view.glance && view.glance.tone ? view.look.tone(view.glance.tone) : Util.alpha(view.look.fg, 0.9)
  }

  // Dark glass, a faint ring, and a glint.
  Item {
    visible: view.face === "lens"
    anchors.right: parent.right
    anchors.rightMargin: view.look.s(11)
    anchors.verticalCenter: parent.verticalCenter
    width: view.look.s(12)
    height: width

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Qt.darker(view.look.surface, 1.6)
      border.width: Math.max(1, view.look.s(1))
      border.color: Util.alpha(view.look.accent, 0.28)
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.42
      height: width
      radius: width / 2
      color: Util.alpha(view.look.accent, 0.35)
    }

    Rectangle {
      x: parent.width * 0.26
      y: parent.height * 0.22
      width: parent.width * 0.2
      height: width
      radius: width / 2
      color: Qt.rgba(1, 1, 1, 0.55)
    }
  }
}
