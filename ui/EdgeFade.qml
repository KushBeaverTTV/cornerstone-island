import QtQuick

// Where scrolling text meets the island's edge: thin slices in the body's
// own vertical gradient, each a little more see-through, so the fade
// matches the body exactly without an offscreen mask.
Row {
  id: fade

  property bool trailing: false
  property real span: 12
  property color shadeTop: "black"
  property color shadeBottom: "black"

  layoutDirection: trailing ? Qt.RightToLeft : Qt.LeftToRight

  Repeater {
    model: 6
    Rectangle {
      required property int index
      width: fade.span / 6
      height: fade.height
      opacity: 1 - index / 6
      gradient: Gradient {
        GradientStop { position: 0; color: fade.shadeTop }
        GradientStop { position: 1; color: fade.shadeBottom }
      }
    }
  }
}
