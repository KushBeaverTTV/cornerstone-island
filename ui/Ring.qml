import QtQuick
import QtQuick.Shapes
import qs.Commons

// A thin ring filling clockwise from twelve o'clock. Vector paths, no
// offscreen layer, so it stays crisp at any scale.
Item {
  id: ring

  property var look: null
  property real progress: 0
  property color color: "white"
  property real lineWidth: 2.5

  readonly property real radius: Math.max(0, Math.min(width, height) / 2 - lineWidth / 2)
  property real shown: Math.min(1, Math.max(0, progress))

  Behavior on shown {
    NumberAnimation { duration: ring.look ? ring.look.ms(240) : 240; easing.type: Easing.OutCubic }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeColor: Util.alpha(ring.color, 0.22)
      strokeWidth: ring.lineWidth
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: ring.radius; radiusY: ring.radius
        startAngle: 0; sweepAngle: 360
      }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.color
      strokeWidth: ring.lineWidth
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: ring.radius; radiusY: ring.radius
        startAngle: -90; sweepAngle: ring.shown * 360
      }
    }
  }
}
