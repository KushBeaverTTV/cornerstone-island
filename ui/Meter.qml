import QtQuick
import qs.Commons

// A slim bar that fills from the left: a level, a progress, or (with
// `seekable`) an interactive slider (song position or source volume) that
// grows a knob under the pointer and supports clicking, dragging and scrolling.
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
  // Emit `seek` live during press and drag (used for volume); when false,
  // previews smoothly while dragging and commits on release (used for seek).
  property bool liveDrag: false
  // Accept wheel events and emit `wheeled` instead of passing them through.
  property bool wheelEnabled: false

  signal seek(real fraction)
  signal wheeled(int delta)

  property bool dragging: false
  property real dragValue: 0

  readonly property real fraction: Math.min(1, Math.max(0, dragging ? dragValue : value))
  readonly property bool hot: seekable && (mouse.containsMouse || dragging)
  readonly property real barHeight: hot ? thickness * 1.4 : thickness

  implicitHeight: thickness * 3

  function clampAt(px) {
    return width > 0 ? Math.min(1, Math.max(0, px / width)) : 0
  }

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
        enabled: !meter.seekable && !meter.dragging
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
      x: Math.max(0, Math.min(bar.width - d, fill.width - d / 2))
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
    enabled: meter.seekable || meter.wheelEnabled
    hoverEnabled: true
    cursorShape: meter.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onPressed: function(event) {
      if (!meter.seekable) return
      var f = meter.clampAt(event.x)
      meter.dragValue = f
      meter.dragging = true
      if (meter.liveDrag) meter.seek(f)
    }
    onPositionChanged: function(event) {
      if (!meter.dragging) return
      var f = meter.clampAt(event.x)
      meter.dragValue = f
      if (meter.liveDrag) meter.seek(f)
    }
    onReleased: function(event) {
      if (!meter.dragging) return
      var f = meter.clampAt(event.x)
      meter.dragging = false
      meter.seek(f)
    }
    onCanceled: meter.dragging = false
    onWheel: function(wheel) {
      if (meter.wheelEnabled) {
        wheel.accepted = true
        meter.wheeled(wheel.angleDelta.y)
      } else {
        wheel.accepted = false
      }
    }
  }
}
