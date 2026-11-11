import QtQuick

// One line of text that scrolls when it does not fit: it rests at the start
// for a moment, then slides left until a second copy, one gap behind,
// stands where the first began, and starts over, so there is no visible
// seam. Text that fits just sits still. The ends fade into the island body.
Item {
  id: ticker

  property var look: null
  property string text: ""
  property color color: "white"
  property bool mono: false
  property real size: 12
  property int weight: Font.DemiBold
  // False holds the text where it is (music paused).
  property bool moving: true
  property real speed: 30          // pixels per second
  property real gap: 40
  property real fadeWidth: 12
  // The body behind it, top and bottom, for the fades to blend into.
  property color fadeTop: "black"
  property color fadeBottom: "black"

  readonly property bool overflows: first.implicitWidth > width + 1
  readonly property bool still: !!look && look.still
  readonly property real cycle: first.implicitWidth + gap

  clip: true
  implicitHeight: first.implicitHeight

  Row {
    id: strip
    anchors.verticalCenter: parent.verticalCenter
    spacing: ticker.gap

    Label {
      id: first
      look: ticker.look
      mono: ticker.mono
      size: ticker.size
      weight: ticker.weight
      color: ticker.color
      text: ticker.text
      // With motion off, a long line is cut short instead of moving.
      width: ticker.still && ticker.overflows ? ticker.width : implicitWidth
      elide: ticker.still ? Text.ElideRight : Text.ElideNone
    }

    Label {
      visible: ticker.overflows && !ticker.still
      look: ticker.look
      mono: ticker.mono
      size: ticker.size
      weight: ticker.weight
      color: ticker.color
      text: ticker.text
      elide: Text.ElideNone
    }
  }

  SequentialAnimation {
    id: scroll
    loops: Animation.Infinite
    running: ticker.overflows && !ticker.still && ticker.visible && ticker.width > 0
    paused: running && !ticker.moving
    PauseAnimation { duration: 1400 }
    NumberAnimation {
      target: strip
      property: "x"
      from: 0
      to: -ticker.cycle
      duration: Math.max(1000, ticker.cycle / Math.max(1, ticker.speed) * 1000)
    }
    onRunningChanged: if (!running) strip.x = 0
  }

  // A new line starts from the beginning.
  onTextChanged: {
    strip.x = 0
    if (scroll.running) scroll.restart()
  }

  EdgeFade {
    anchors.left: parent.left
    visible: ticker.overflows && !ticker.still
    height: ticker.height
    span: ticker.fadeWidth
    shadeTop: ticker.fadeTop
    shadeBottom: ticker.fadeBottom
  }

  EdgeFade {
    anchors.right: parent.right
    visible: ticker.overflows && !ticker.still
    trailing: true
    height: ticker.height
    span: ticker.fadeWidth
    shadeTop: ticker.fadeTop
    shadeBottom: ticker.fadeBottom
  }
}
