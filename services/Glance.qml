import QtQuick
import Quickshell
import "../lib/Glyphs.js" as Glyphs
import "../lib/Format.js" as Format

// What the resting island shows with "idleFace": "ticker": a glance that
// turns over every few seconds through the time, the date, the battery,
// the next meeting, today's holiday and the silenced state. With "clock",
// just the time.
Item {
  id: glance

  property var island: null

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  readonly property var items: {
    var list = []
    var date = clock.date
    // Qt only gives a 12-hour "h" with AM/PM in the same format, so it is
    // formatted with it and the suffix dropped: "10:57", not "22:57".
    var time = island.settings.twelveHour
      ? Qt.formatDateTime(date, "h:mm AP").replace(/\s*[AaPp][Mm]$/, "")
      : Qt.formatDateTime(date, "HH:mm")
    list.push({ key: "time", text: time })
    if (island.settings.idleFace === "clock") return list

    list.push({ key: "date", text: Qt.formatDateTime(date, "ddd d") })
    var power = island.power
    if (power.present)
      list.push({ key: "battery", text: Glyphs.battery(power.level, power.charging) + " " + Format.percent(power.level),
                  tone: power.charging ? "green" : (power.low ? "urgent" : "") })
    var next = island.calendar.next
    var t = date.getTime()
    if (next && next.start > t && next.start - t < 12 * 3600000)
      list.push({ key: "event", text: Glyphs.CALENDAR + " " + Format.until(next.start, t), tone: "accent" })
    var holidays = island.calendar.todayAllDay
    if (holidays.length > 0) list.push({ key: "festival", text: Glyphs.SPARKLE + " " + Format.clip(holidays[0], 28), tone: "orange" })
    if (island.notices.silenced) list.push({ key: "dnd", text: Glyphs.BELL_OFF + " Silenced", tone: "orange" })
    return list
  }

  property int index: 0
  readonly property var current: items.length > 0 ? items[index % items.length] : null

  // Turn over only while the island is resting; nothing to animate under a
  // live activity.
  Timer {
    interval: 5000
    repeat: true
    running: glance.island.settings.idleFace === "ticker" && glance.island.stage.resting && glance.items.length > 1
    onTriggered: glance.index = (glance.index + 1) % glance.items.length
  }
}
