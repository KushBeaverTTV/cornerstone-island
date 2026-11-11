import QtQuick
import qs.Commons

// A slim bar that fills from the left: a level, a progress, or (with
// `seekable`) the song's position, which grows a knob under the pointer and
// reports where it was clicked.
Item {
  id: meter

  property var look: null
  property real value: 0
  property color color: look ? look.fg : "white"
  property color trackColor: Util.alpha(look ? look.fg : "white", 0.16)
  property real thickness: 5
  property bool seekable: false
  property bool knob: false
  // A fill that shades from faint to full, like the player's bar.
  property bool shaded: false

  signal seek(real fraction)

  readonly property real fraction: Math.min(1, Math.max(0, value))
  readonly property bool hot: seekable && mouse.containsMouse
  readonly property real barHeight: hot ? thickness * 1.4 : thickness

  implicitHeight: thickness * 3

  Rectangle {
    id: bar
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: meter.barHeight
    radius: height / 2
    color: meter.trackColor
    Behavior on height { NumberAnimation { duration: meter.look ? meter.look.ms(120) : 120; easing.type: Easing.OutCubic } }

    Rectangle {
      id: fill
      height: parent.height
      radius: height / 2
      width: Math.max(meter.fraction > 0 ? height : 0, parent.width * meter.fraction)
      color: meter.color
      gradient: meter.shaded ? shade : null
      Behavior on width {
        enabled: !meter.seekable
        NumberAnimation { duration: meter.look ? meter.look.ms(180) : 180; easing.type: Easing.OutCubic }
      }
    }

    Gradient {
      id: shade
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Util.alpha(meter.color, 0.55) }
      GradientStop { position: 1; color: meter.color }
    }

    Rectangle {
      visible: meter.knob
      property real d: meter.thickness * (meter.hot ? 2.6 : 1.8)
      width: d
      height: d
      radius: d / 2
      x: fill.width - d / 2
      anchors.verticalCenter: parent.verticalCenter
      color: meter.color
      border.width: Math.max(1, meter.thickness * 0.4)
      border.color: meter.look ? meter.look.bodyAt(0.6) : "black"
      Behavior on d { NumberAnimation { duration: meter.look ? meter.look.ms(140) : 140; easing.type: Easing.OutCubic } }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: meter.seekable
    hoverEnabled: true
    cursorShape: meter.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: function(event) { meter.seek(event.x / width) }
  }
}
