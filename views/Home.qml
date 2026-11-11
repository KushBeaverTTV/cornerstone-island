import QtQuick
import Quickshell
import "../ui"
import "../lib/Format.js" as Format
import "../lib/Glyphs.js" as Glyphs

// What the island opens into when nothing is live: the time, the date (or
// the next meeting), the battery, and one-tap timers, a stopwatch and the
// calendar.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property int pad: look.s(26)
  readonly property var next: island.calendar.next
  readonly property var power: island.power

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Column {
    x: view.pad
    y: view.look.s(18)
    spacing: view.look.s(1)

    Label {
      look: view.look
      mono: true
      size: 30
      weight: Font.Light
      font.letterSpacing: -1
      elide: Text.ElideNone
      text: Qt.formatDateTime(clock.date, view.island.settings.clockFormat)
    }

    // The date, or the next meeting, opens the calendar.
    Label {
      id: dateLine
      width: view.look.s(270)
      look: view.look
      size: 12
      font.underline: dateMouse.containsMouse
      color: view.next ? view.look.accent : view.look.fgDim
      text: view.next
        ? Glyphs.CALENDAR + "  " + view.next.title + "  ·  "
          + Qt.formatDateTime(new Date(view.next.start), view.island.settings.twelveHour ? "h:mm AP" : "HH:mm")
        : Qt.formatDateTime(clock.date, "dddd, d MMMM")
          + (view.island.calendar.todayAllDay.length > 0 ? "  ·  " + view.island.calendar.todayAllDay.join(", ") : "")

      MouseArea {
        id: dateMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.island.stage.openCalendar()
      }
    }
  }

  Column {
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    y: view.look.s(20)
    spacing: view.look.s(2)
    visible: view.power.present

    Label {
      anchors.right: parent.right
      look: view.look
      mono: true
      size: 26
      elide: Text.ElideNone
      text: Glyphs.battery(view.power.level, view.power.charging)
      color: view.power.charging ? view.look.green : (view.power.low ? view.look.urgent : view.look.fg)
    }

    Label {
      anchors.right: parent.right
      look: view.look
      mono: true
      size: 11
      elide: Text.ElideNone
      text: Format.percent(view.power.level) + (view.power.charging ? " · charging" : "")
      color: view.look.fgDim
    }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.look.s(16)
    spacing: view.look.s(8)

    Repeater {
      model: [
        { text: Glyphs.TIMER + " 5 min", seconds: 300 },
        { text: Glyphs.TIMER + " 15 min", seconds: 900 },
        { text: Glyphs.TIMER + " 25 min", seconds: 1500 },
        { text: Glyphs.STOPWATCH + " Stopwatch", seconds: 0 },
        { text: Glyphs.CALENDAR, seconds: -1 }
      ]

      Chip {
        required property var modelData
        look: view.look
        tone: modelData.seconds > 0 ? view.look.orange : view.look.accent
        text: modelData.text
        onClicked: {
          if (modelData.seconds < 0) { view.island.stage.openCalendar(); return }
          if (modelData.seconds > 0) view.island.clocks.startTimer(modelData.seconds, "")
          else view.island.clocks.toggleStopwatch()
          view.island.stage.done()
        }
      }
    }
  }
}
