import QtQuick
import qs.Commons

// A round glyph button: transport controls, ✕, back, month arrows.
Item {
  id: button

  property var look: null
  property string glyph: ""
  property real glyphSize: 18
  property color color: look ? look.fg : "white"
  property bool available: true
  // A faint disc behind it even at rest (the ✕ on a notification).
  property bool backed: false

  signal clicked()

  implicitWidth: Math.round((look ? look.f(glyphSize) : glyphSize) * 2)
  implicitHeight: implicitWidth
  scale: mouse.pressed && available ? 0.88 : 1

  Behavior on scale { NumberAnimation { duration: button.look ? button.look.ms(120) : 120; easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Util.alpha(button.color, !button.available ? 0
      : (mouse.pressed ? 0.24 : (mouse.containsMouse ? 0.14 : (button.backed ? 0.08 : 0))))
    Behavior on color { ColorAnimation { duration: button.look ? button.look.ms(120) : 120 } }
  }

  Label {
    anchors.centerIn: parent
    look: button.look
    mono: true
    size: button.glyphSize
    text: button.glyph
    color: button.color
    opacity: button.available ? 1 : 0.35
    elide: Text.ElideNone
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (button.available) button.clicked()
  }
}
