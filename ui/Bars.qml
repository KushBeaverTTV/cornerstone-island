import QtQuick

// The little equaliser beside the music: bars drift to new heights while
// something plays and settle low when it pauses. It is decoration, not a
// meter, so with the shell's animations off it stands still.
Row {
  id: bars

  property var look: null
  property bool playing: false
  property color color: "white"
  property int count: 4
  property real barWidth: 3
  property real maxHeight: 14

  readonly property bool moving: playing && visible && !(look && look.still)

  spacing: Math.max(1, Math.round(barWidth * 0.75))
  height: maxHeight

  Repeater {
    id: repeater
    model: bars.count

    Rectangle {
      required property int index
      property real level: [0.55, 0.85, 0.45, 0.7][index % 4]

      anchors.verticalCenter: parent.verticalCenter
      width: bars.barWidth
      radius: width / 2
      height: Math.max(bars.barWidth, bars.maxHeight * (bars.playing ? level : 0.2))
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(bars.color, 1.35) }
        GradientStop { position: 1; color: bars.color }
      }

      Behavior on height { NumberAnimation { duration: bars.look ? bars.look.ms(180) : 180; easing.type: Easing.OutCubic } }
    }
  }

  Timer {
    interval: 200
    repeat: true
    running: bars.moving
    onTriggered: {
      for (var i = 0; i < repeater.count; i++) {
        var bar = repeater.itemAt(i)
        if (bar) bar.level = 0.25 + Math.random() * 0.75
      }
    }
  }
}
