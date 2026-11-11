import QtQuick
import QtQuick.Shapes

// The outline of the notch-style island: down from the screen's edge through
// a concave ear, along the body with rounded lower corners, and back up
// through the other ear. Open at the top (the screen's edge); add a
// PathLine back to the start to close it for a fill.
ShapePath {
  property real left: 0      // the body's left edge
  property real right: 0     // the body's right edge
  property real depth: 0     // the body's height
  property real corner: 0    // its lower corner radius
  property real ear: 0       // the ears' radius

  startX: left - ear; startY: 0
  PathArc { x: left; y: ear; radiusX: ear; radiusY: ear; direction: PathArc.Clockwise }
  PathLine { x: left; y: depth - corner }
  PathArc { x: left + corner; y: depth; radiusX: corner; radiusY: corner; direction: PathArc.Counterclockwise }
  PathLine { x: right - corner; y: depth }
  PathArc { x: right; y: depth - corner; radiusX: corner; radiusY: corner; direction: PathArc.Counterclockwise }
  PathLine { x: right; y: ear }
  PathArc { x: right + ear; y: 0; radiusX: ear; radiusY: ear; direction: PathArc.Clockwise }
}
