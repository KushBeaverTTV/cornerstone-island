import QtQuick
import qs.Commons
import "../ui"
import "../lib/Format.js" as Format
import "../lib/Glyphs.js" as Glyphs

// The timer or stopwatch, opened: the time large, with +1 minute (or reset),
// pause and resume in the activity's colour, and cancel.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var clocks: island.clocks
  readonly property bool timer: clocks.timerActive
  readonly property bool paused: timer ? clocks.timerPaused : !clocks.stopwatchRunning
  readonly property color hue: timer ? look.orange : look.accent
  readonly property color tone: paused ? look.fgDim : hue
  readonly property int pad: look.s(24)

  Column {
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: view.look.s(2)

    Label {
      look: view.look
      size: 12
      text: view.timer ? (view.clocks.timerLabel || "Timer") : "Stopwatch"
      color: view.look.fgDim
    }

    Label {
      look: view.look
      mono: true
      size: 34
      weight: Font.Light
      font.letterSpacing: -1
      elide: Text.ElideNone
      text: view.timer ? Format.clock(Math.ceil(view.clocks.timerLeft / 1000)) : Format.clock(view.clocks.stopwatchElapsed / 1000, true)
      color: view.tone
    }
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: view.pad - view.look.s(6)
    anchors.verticalCenter: parent.verticalCenter
    spacing: view.look.s(8)

    RoundButton {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      glyph: view.timer ? Glyphs.PLUS : Glyphs.RESET
      onClicked: view.timer ? view.clocks.addMinute() : view.clocks.resetStopwatch()
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(46)
      height: width
      radius: width / 2
      color: Util.alpha(view.hue, toggle.pressed ? 0.4 : (toggle.containsMouse ? 0.32 : 0.26))
      scale: toggle.pressed ? 0.92 : 1

      Behavior on scale { NumberAnimation { duration: view.look.ms(120); easing.type: Easing.OutCubic } }

      Label {
        anchors.centerIn: parent
        look: view.look
        mono: true
        size: 20
        elide: Text.ElideNone
        text: view.paused ? Glyphs.PLAY : Glyphs.PAUSE
        color: view.hue
      }

      MouseArea {
        id: toggle
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.timer ? view.clocks.toggleTimer() : view.clocks.toggleStopwatch()
      }
    }

    RoundButton {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      glyph: Glyphs.CLOSE
      onClicked: {
        if (view.timer) view.clocks.cancelTimer()
        else view.clocks.resetStopwatch()
        view.island.stage.done()
      }
    }
  }
}
