import QtQuick
import qs.Commons

// A pill with a label: "5 min", "Stop", "Clear all", "Paste", an action of a
// notification. `solid` fills it with the tone (the one main action).
Rectangle {
  id: chip

  property var look: null
  property string text: ""
  property color tone: look ? look.fg : "white"
  property bool solid: false
  property real textSize: 12
  // Stretch to a set width (action rows); otherwise fit the label.
  property real fixedWidth: 0

  signal clicked()

  height: look ? look.s(30) : 30
  width: fixedWidth > 0 ? fixedWidth : label.implicitWidth + (look ? look.s(26) : 26)
  radius: height / 2
  color: solid ? Qt.lighter(tone, mouse.pressed ? 0.9 : (mouse.containsMouse ? 1.08 : 1))
               : Util.alpha(tone, mouse.pressed ? 0.3 : (mouse.containsMouse ? 0.2 : 0.12))
  scale: mouse.pressed ? 0.95 : 1

  Behavior on scale { NumberAnimation { duration: chip.look ? chip.look.ms(120) : 120; easing.type: Easing.OutCubic } }
  Behavior on color { ColorAnimation { duration: chip.look ? chip.look.ms(120) : 120 } }

  Label {
    id: label
    anchors.centerIn: parent
    width: chip.fixedWidth > 0 ? chip.width - (chip.look ? chip.look.s(16) : 16) : implicitWidth
    horizontalAlignment: Text.AlignHCenter
    look: chip.look
    size: chip.textSize
    weight: Font.DemiBold
    text: chip.text
    color: chip.solid ? (chip.look ? chip.look.surface : "black") : chip.tone
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.clicked()
  }
}
