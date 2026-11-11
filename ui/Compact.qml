import QtQuick

// The layout every compact activity shares: something on the leading edge
// (a cover, a glyph, a ring), something on the trailing edge (a time, a
// count, the equaliser), and optionally a line in between. The two edges sit
// either side of where a camera cutout would be, the way iOS lays out its
// island.
Item {
  id: frame

  property var look: null
  property Item lead: null
  property Item trail: null
  property Item middle: null
  // Unscaled distances from the island's ends, and around the middle.
  property real leadInset: 13
  property real trailInset: 14
  property real gap: 10

  Item {
    id: leadBox
    anchors.left: parent.left
    anchors.leftMargin: frame.look ? frame.look.s(frame.leadInset) : frame.leadInset
    height: parent.height
    width: frame.lead ? frame.lead.width : 0
  }

  Item {
    id: trailBox
    anchors.right: parent.right
    anchors.rightMargin: frame.look ? frame.look.s(frame.trailInset) : frame.trailInset
    height: parent.height
    width: frame.trail ? frame.trail.width : 0
  }

  Item {
    id: middleBox
    anchors.left: leadBox.right
    anchors.right: trailBox.left
    anchors.leftMargin: frame.look ? frame.look.s(frame.gap) : frame.gap
    anchors.rightMargin: frame.look ? frame.look.s(frame.gap) : frame.gap
    height: parent.height
  }

  function adopt(child, box, stretch) {
    if (!child) return
    child.parent = box
    child.anchors.verticalCenter = box.verticalCenter
    if (stretch) {
      child.anchors.left = box.left
      child.anchors.right = box.right
    }
  }

  onLeadChanged: adopt(lead, leadBox, false)
  onTrailChanged: adopt(trail, trailBox, false)
  onMiddleChanged: adopt(middle, middleBox, true)
  Component.onCompleted: {
    adopt(lead, leadBox, false)
    adopt(trail, trailBox, false)
    adopt(middle, middleBox, true)
  }
}
