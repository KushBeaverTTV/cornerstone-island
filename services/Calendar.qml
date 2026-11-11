import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Ics.js" as Ics
import "../lib/Format.js" as Format

// The next meeting and a month of events, from iCalendar feeds. Any
// calendar that can publish an .ics link works (Google's "secret address in
// iCal format", an iCloud public calendar, Outlook's "publish a calendar",
// Nextcloud, Fastmail), and so do local .ics files.
//
// Where the links come from:
//   - "calendars" in the island's shell.json entry (written by hand);
//   - links added in the calendar view, kept in the island's own file
//     ~/.config/omarchy/dynamic-island/calendars.json (writing shell.json
//     would make the shell rebuild the island in the middle of adding);
//   - the public holiday calendar of the country ("holidays": "auto" follows
//     the system timezone; the view can pick another or turn it off).
//
// Feeds are fetched every 15 minutes, read once into events, and every
// question (next meeting, a month, today's all-day events) is answered from
// those events.
Item {
  id: calendar

  property var island: null

  readonly property string ownDir: Quickshell.env("HOME") + "/.config/omarchy/dynamic-island"

  // ---- sources
  property var added: []
  property string detectedCountry: ""
  property string holidayChoice: "auto"

  readonly property string holidayCountry: {
    var choice = holidayChoice === "auto" ? island.settings.holidays : holidayChoice
    if (choice === "auto") choice = detectedCountry
    return choice === "off" ? "" : String(choice || "").toUpperCase()
  }
  readonly property string holidayFeed: Ics.holidayFeed(holidayCountry)
  readonly property string holidayName: { var h = Ics.holiday(holidayCountry); return h ? h.name : "" }

  readonly property var sources: {
    var out = []
    island.settings.calendars.concat(added).concat(holidayFeed ? [holidayFeed] : []).forEach(function(link) {
      if (link && out.indexOf(link) === -1) out.push(link)
    })
    return out
  }

  function setHolidays(code) {
    holidayChoice = String(code || "auto")
    prefsFile.setText(JSON.stringify({ holidays: holidayChoice }, null, 2) + "\n")
  }

  function add(link) {
    var l = String(link || "").trim()
    if (l === "") return
    justAdded = l
    lastResult = null
    added = added.filter(function(x) { return x !== l }).concat([l])
    addedFile.setText(JSON.stringify(added, null, 2) + "\n")
  }

  function remove(link) {
    var l = String(link || "")
    if (l === holidayFeed) { setHolidays("off"); return }
    if (added.indexOf(l) !== -1) {
      added = added.filter(function(x) { return x !== l })
      addedFile.setText(JSON.stringify(added, null, 2) + "\n")
    }
    // A hand-written one comes out of shell.json too (that reloads the
    // island, which is fine for a removal).
    if (island.settings.calendars.indexOf(l) !== -1)
      island.settings.save({ calendars: island.settings.calendars.filter(function(x) { return x !== l }) })
  }

  // Timezone -> ISO country (Asia/Kolkata -> IN) from tzdata's zone.tab.
  Process {
    running: true
    command: ["sh", "-c", "tz=$(timedatectl show -p Timezone --value 2>/dev/null || readlink /etc/localtime | sed 's#.*zoneinfo/##'); " +
                          "awk -v tz=\"$tz\" '$3==tz{print $1; exit}' /usr/share/zoneinfo/zone.tab 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: calendar.detectedCountry = String(text || "").trim() }
  }

  Process {
    running: true
    command: ["mkdir", "-p", calendar.ownDir]
    onExited: { addedFile.reload(); prefsFile.reload() }
  }

  FileView {
    id: addedFile
    path: calendar.ownDir + "/calendars.json"
    printErrors: false
    atomicWrites: true
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var list = JSON.parse(text() || "[]")
        if (Array.isArray(list)) calendar.added = list.map(String).slice(0, 50)
      } catch (e) {}
    }
  }

  FileView {
    id: prefsFile
    path: calendar.ownDir + "/prefs.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try { var p = JSON.parse(text() || "{}"); if (p.holidays) calendar.holidayChoice = String(p.holidays) } catch (e) {}
    }
  }

  // ---- events
  property var events: []          // every VEVENT read from the feeds
  property double now: Date.now()
  property int revision: 0

  // Occurrences from an hour ago to a week ahead, timed events only.
  readonly property var upcoming: { revision; return Ics.between(events, now - 3600000, now + 8 * 86400000, false) }

  // The next one that has not ended.
  readonly property var next: {
    for (var i = 0; i < upcoming.length; i++)
      if (upcoming[i].end > now) return upcoming[i]
    return null
  }

  // Live from `calendarLeadMinutes` before it starts to 5 minutes after.
  readonly property bool soon: next !== null && next.start - now <= island.settings.calendarLeadMinutes * 60000
    && now - next.start < 5 * 60000
  readonly property bool started: next !== null && next.start <= now
  readonly property string countdown: next ? Format.until(next.start, now) : ""

  // Today's all-day events (holidays, festivals, birthdays) for the glance.
  readonly property var todayAllDay: {
    revision
    var d = new Date(now)
    var from = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    return Ics.between(events, from, from + 86400000 - 1, true)
      .filter(function(o) { return o.allDay }).map(function(o) { return o.title })
  }

  // One month, grouped by day (with a margin either side for the grid).
  function month(year, monthIndex) {
    revision
    var from = new Date(year, monthIndex, 1).getTime() - 7 * 86400000
    var to = new Date(year, monthIndex + 1, 1).getTime() + 14 * 86400000
    return Ics.byDay(Ics.between(events, from, to, true))
  }

  // One heads-up as a meeting starts.
  property string announced: ""

  Timer {
    interval: 20000
    repeat: true
    triggeredOnStart: true
    running: calendar.events.length > 0
    onTriggered: {
      calendar.now = Date.now()
      var ev = calendar.next
      if (!ev || ev.start > calendar.now || calendar.now - ev.start >= 60000) return
      var key = ev.title + "@" + ev.start
      if (calendar.announced === key) return
      calendar.announced = key
      calendar.island.hud.show({ layout: "toast", title: ev.title || "Event", body: "Starting now",
                                 icon: "\u{f00ed}", tone: "accent", duration: 8000 })
    }
  }

  // ---- fetching
  // Each source is announced before its contents with a status line
  // ("@@ISLAND-SOURCE <n> ok", or "HTTP 404", "unreachable", "file not
  // found", "too large", "not a calendar"), so a bad link can be reported
  // instead of silently showing nothing. Everything read is capped, since
  // the shell keeps it in memory: 4 MiB a source (a busy calendar is a few
  // hundred KiB), local paths must be regular files, and the whole output
  // stops at 16 MiB. Links travel as arguments, never inside the script.
  readonly property string fetchScript: [
    'max=4194304',
    '{ i=0',
    'for u in "$@"; do',
    '  s="${u/#\\~/$HOME}"; t=$(mktemp); h=$(mktemp); st=ok',
    '  case "$s" in webcal://*) s="https://${s#webcal://}" ;; esac',
    '  case "$s" in',
    '    http://*|https://*)',
    '      curl -sL --max-time 20 --max-filesize "$max" -D "$h" -o - "$s" 2>/dev/null | head -c $((max + 1)) > "$t"',
    '      rc=${PIPESTATUS[0]}',
    "      code=$(awk '/^HTTP\\//{c=$2} END{print c+0}' \"$h\")",
    '      if [ "$rc" = 63 ] || [ "$(wc -c < "$t")" -gt "$max" ]; then st="too large"',
    '      elif [ "$code" = 0 ]; then st=unreachable',
    '      elif [ "$code" != 200 ]; then st="HTTP $code"; fi ;;',
    '    *)',
    '      if [ ! -f "$s" ]; then st="file not found"',
    '      elif [ "$(wc -c < "$s")" -gt "$max" ]; then st="too large"',
    '      else head -c "$max" "$s" > "$t"; fi ;;',
    '  esac',
    '  [ "$st" = ok ] && ! grep -q "BEGIN:VCALENDAR" "$t" && st="not a calendar"',
    '  echo "@@ISLAND-SOURCE $i $st"; [ "$st" = ok ] && cat "$t"; echo',
    '  rm -f "$t" "$h"; i=$((i+1))',
    'done; } | head -c 16777216'
  ].join("\n")

  // link -> "ok" or what went wrong on the last fetch.
  property var status: ({})
  property var fetching: []
  property bool fetchAgain: false
  // The feeds as last fetched, kept so a demo can add to them.
  property string fetchedText: ""

  function statusOf(link) { return status[String(link)] || "" }

  Process {
    id: fetch
    stdout: StdioCollector {
      onStreamFinished: {
        var found = {}
        String(text || "").split("\n").forEach(function(line) {
          var m = /^@@ISLAND-SOURCE (\d+) (.*)$/.exec(line.replace(/\r$/, ""))
          if (m && calendar.fetching[+m[1]] !== undefined) found[calendar.fetching[+m[1]]] = m[2]
        })
        calendar.status = found
        calendar.fetchedText = String(text || "")
        calendar.load(calendar.fetchedText)
        calendar.reportAdded()
        if (calendar.fetchAgain) {
          calendar.fetchAgain = false
          Qt.callLater(calendar.refresh)
        }
      }
    }
  }

  function load(text) {
    events = Ics.read(text)
    now = Date.now()
    revision++
  }

  function refresh() {
    if (sources.length === 0) { fetchedText = ""; load(""); return }
    // A fetch in flight has the old list: go again when it ends.
    if (fetch.running) { fetchAgain = true; return }
    fetching = sources.slice()
    fetch.command = ["bash", "-c", fetchScript, "bash"].concat(fetching)
    fetch.running = true
  }

  onSourcesChanged: refresh()

  Timer {
    interval: 15 * 60000
    repeat: true
    running: calendar.sources.length > 0
    onTriggered: calendar.refresh()
  }

  // ---- adding a link: say how it went, once it has really been fetched.
  property string justAdded: ""
  // Shown inside the calendar view (a HUD would be hidden behind it):
  // { ok: bool, text: string }.
  property var lastResult: null
  Timer { id: resultTimer; interval: 7000; onTriggered: calendar.lastResult = null }

  function reportAdded() {
    var link = justAdded
    var st = link ? statusOf(link) : ""
    if (st === "") return
    justAdded = ""
    resultTimer.restart()
    if (st === "ok") {
      var count = Ics.between(events, Date.now() - 30 * 86400000, Date.now() + 60 * 86400000, true).length
      var counted = count + (count === 1 ? " event" : " events")
      lastResult = { ok: true, text: "\u{f012c}  Calendar added · " + counted + " around now" }
      island.hud.show({ key: "calendar", layout: "label", label: "Calendar added", icon: "\u{f00ed}",
                        valueText: counted, tone: "green", duration: 2600 })
      return
    }
    // Google's "public address" answers 404 unless the calendar is public;
    // the secret address is almost always what was meant.
    var google = link.indexOf("calendar.google.com") !== -1 && link.indexOf("/public/") !== -1 && st === "HTTP 404"
    lastResult = { ok: false, text: google
      ? "\u{f0026}  Google refused the public address (404). Use \"Secret address in iCal format\"."
      : "\u{f0026}  That link didn't work: " + st }
    island.hud.show({ key: "calendar", layout: "label",
                      label: google ? "Use Google's secret iCal address" : "Calendar link didn't work",
                      icon: "\u{f00ee}", valueText: google ? "404" : st, tone: "urgent", duration: 5000 })
  }

  // ---- demo: a meeting in eight minutes and a small month around today,
  // on top of the real feeds.
  function stampOf(t) {
    var d = new Date(t)
    return d.getFullYear() + Format.pad2(d.getMonth() + 1) + Format.pad2(d.getDate())
      + "T" + Format.pad2(d.getHours()) + Format.pad2(d.getMinutes()) + "00"
  }

  function demo() {
    var start = Date.now() + 8 * 60000
    var today = new Date()
    var midnight = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime()
    function at(days, h, m) { return midnight + days * 86400000 + (h * 60 + m) * 60000 }
    var feed = [
      "BEGIN:VCALENDAR",
      "BEGIN:VEVENT", "SUMMARY:Design review", "DTSTART:" + stampOf(start), "DTEND:" + stampOf(start + 1800000),
      "LOCATION:https://meet.google.com/abc-defg-hij", "END:VEVENT",
      "BEGIN:VEVENT", "UID:standup", "SUMMARY:Standup", "DTSTART:" + stampOf(at(-20, 10, 0)),
      "DTEND:" + stampOf(at(-20, 10, 15)), "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", "END:VEVENT",
      "BEGIN:VEVENT", "SUMMARY:Lunch with Priya", "DTSTART:" + stampOf(at(1, 13, 0)), "DTEND:" + stampOf(at(1, 14, 0)), "END:VEVENT",
      "BEGIN:VEVENT", "SUMMARY:Omarchy release", "DTSTART;VALUE=DATE:" + stampOf(at(4, 0, 0)).slice(0, 8), "END:VEVENT",
      "END:VCALENDAR"
    ].join("\r\n") + "\r\n"
    load(feed + fetchedText)
  }
}
