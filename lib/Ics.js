.pragma library

// A small iCalendar reader, enough for "what is next" and a month view.
//
// Feeds are read once into events (`read`), and occurrences in any window
// are worked out from those (`between`), so the month view and the idle
// glance never re-read the raw text.
//
// Understood: folded lines; UTC, floating and TZID times (a TZID time is
// taken as local time); all-day events; DAILY and WEEKLY repeats with
// INTERVAL, BYDAY, COUNT and UNTIL; MONTHLY on a date or on a weekday
// ("2nd Tuesday", "last Friday"); YEARLY on a date; EXDATE; and moved or
// edited single occurrences (RECURRENCE-ID), which replace the regular one.
// Cancelled events are left out. Other repeat rules show their first date.

var DAY = 86400000
var WEEKDAYS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
var MAX_EVENTS = 5000

// "20261111T093000Z" / "20261111T093000" / "20261111" -> { time, allDay }
function stamp(value) {
  var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(String(value || "").trim())
  if (!m) return null
  var y = +m[1], mo = +m[2] - 1, d = +m[3]
  if (m[4] === undefined) return { time: new Date(y, mo, d).getTime(), allDay: true }
  var time = m[7] ? Date.UTC(y, mo, d, +m[4], +m[5], +m[6]) : new Date(y, mo, d, +m[4], +m[5], +m[6]).getTime()
  return { time: time, allDay: false }
}

function unescapeText(value) {
  return String(value || "").replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim()
}

// The link worth opening for an event: its URL, else the first meeting link
// in the location or description (Meet, Zoom and Teams put one there).
function linkIn(text) {
  var m = /https?:\/\/[^\s<>"'\\]+/.exec(String(text || ""))
  return m ? m[0] : ""
}

function parseRule(text) {
  var rule = {}
  String(text || "").split(";").forEach(function(part) {
    var eq = part.indexOf("=")
    if (eq > 0) rule[part.slice(0, eq).toUpperCase()] = part.slice(eq + 1)
  })
  if (!rule.FREQ) return null
  var until = rule.UNTIL ? stamp(rule.UNTIL) : null
  return {
    freq: rule.FREQ.toUpperCase(),
    interval: Math.max(1, parseInt(rule.INTERVAL || "1", 10) || 1),
    count: rule.COUNT ? Math.max(0, parseInt(rule.COUNT, 10) || 0) : Infinity,
    until: until ? until.time : Infinity,
    // [{ day: 0..6, nth: 0 (every) | 1..5 | -1..-5 }]
    byDay: (rule.BYDAY || "").split(",").map(function(code) {
      var m = /^([+-]?\d+)?([A-Z]{2})$/.exec(code.trim().toUpperCase())
      return m ? { day: WEEKDAYS.indexOf(m[2]), nth: m[1] ? parseInt(m[1], 10) : 0 } : null
    }).filter(function(d) { return d && d.day >= 0 })
  }
}

// Every VEVENT in the text, as plain objects.
function read(text) {
  var lines = String(text || "").replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
  var events = []
  var ev = null
  for (var i = 0; i < lines.length && events.length < MAX_EVENTS; i++) {
    var line = lines[i]
    if (line === "BEGIN:VEVENT") {
      ev = { uid: "", title: "", start: 0, end: 0, allDay: false, rule: null, exdates: [],
             recurrenceId: 0, cancelled: false, url: "", location: "", description: "" }
      continue
    }
    if (line === "END:VEVENT") {
      if (ev && ev.start && !ev.cancelled) {
        if (!ev.end) ev.end = ev.start + (ev.allDay ? DAY : 3600000)
        ev.url = ev.url || linkIn(ev.location) || linkIn(ev.description)
        delete ev.description
        events.push(ev)
      } else if (ev && ev.cancelled && ev.recurrenceId) {
        // A cancelled single occurrence still has to knock out the regular one.
        events.push(ev)
      }
      ev = null
      continue
    }
    if (!ev) continue
    var colon = line.indexOf(":")
    if (colon < 0) continue
    var name = line.slice(0, colon).split(";")[0].toUpperCase()
    var value = line.slice(colon + 1)
    switch (name) {
    case "UID": ev.uid = value.trim(); break
    case "SUMMARY": ev.title = unescapeText(value).slice(0, 300); break
    case "DTSTART": var s = stamp(value); if (s) { ev.start = s.time; ev.allDay = s.allDay } break
    case "DTEND": var e = stamp(value); if (e) ev.end = e.time; break
    case "RRULE": ev.rule = parseRule(value); break
    case "RECURRENCE-ID": var r = stamp(value); if (r) ev.recurrenceId = r.time; break
    case "URL": ev.url = value.trim(); break
    case "X-GOOGLE-CONFERENCE": ev.url = ev.url || value.trim(); break
    case "LOCATION": ev.location = unescapeText(value).slice(0, 500); break
    case "DESCRIPTION": ev.description = unescapeText(value).slice(0, 4000); break
    case "EXDATE":
      value.split(",").forEach(function(v) { var x = stamp(v); if (x) ev.exdates.push(x.time) })
      break
    case "STATUS": if (value.trim().toUpperCase() === "CANCELLED") ev.cancelled = true; break
    }
  }
  return linkOverrides(events)
}

// A moved or edited occurrence arrives as its own VEVENT with the series'
// UID and the original start in RECURRENCE-ID: the series skips that date
// and the override stands on its own (or, if cancelled, nothing does).
function linkOverrides(events) {
  var series = {}
  events.forEach(function(ev) { if (ev.rule && ev.uid) series[ev.uid] = ev })
  return events.filter(function(ev) {
    if (!ev.recurrenceId) return true
    var parent = series[ev.uid]
    if (parent) parent.exdates.push(ev.recurrenceId)
    return !ev.cancelled
  })
}

function occurrence(ev, start) {
  return { title: ev.title, start: start, end: start + (ev.end - ev.start), allDay: ev.allDay,
           url: ev.url, location: ev.location }
}

// The date of the nth (1-based, or negative from the end) `weekday` in a month.
function nthWeekday(year, month, weekday, nth) {
  if (nth > 0) {
    var first = new Date(year, month, 1).getDay()
    var date = 1 + (weekday - first + 7) % 7 + (nth - 1) * 7
    return date <= new Date(year, month + 1, 0).getDate() ? date : 0
  }
  var lastDate = new Date(year, month + 1, 0).getDate()
  var last = new Date(year, month, lastDate).getDay()
  var back = lastDate - (last - weekday + 7) % 7 + (nth + 1) * 7
  return back >= 1 ? back : 0
}

// Start times of a repeating event, in order, while `keep(time)` says so.
// `keep` returns false once past the window; the walk is also bounded.
function walk(ev, emit, horizon) {
  var rule = ev.rule
  var first = new Date(ev.start)
  var h = first.getHours(), mi = first.getMinutes(), se = first.getSeconds()
  var made = 0
  function offer(t) {
    if (t < ev.start) return true
    if (t > rule.until || t > horizon || made >= rule.count) return false
    made++
    if (ev.exdates.indexOf(t) === -1) emit(t)
    return true
  }

  if (rule.freq === "DAILY" || rule.freq === "WEEKLY") {
    var weekly = rule.freq === "WEEKLY"
    var days = weekly && rule.byDay.length ? rule.byDay.map(function(d) { return d.day }) : [first.getDay()]
    // Weeks are counted from the Monday-first week (iCalendar's default)
    // that holds DTSTART, so "every other week" stays on the right weeks.
    var weekStart = new Date(first.getFullYear(), first.getMonth(), first.getDate() - (first.getDay() + 6) % 7)
    for (var i = 0; i < 4000; i++) {
      var day = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i, h, mi, se)
      var on = weekly
        ? days.indexOf(day.getDay()) !== -1
          && Math.floor(Math.round((day - weekStart) / DAY) / 7) % rule.interval === 0
        : i % rule.interval === 0
      if (on && !offer(day.getTime())) return
    }
    return
  }

  if (rule.freq === "MONTHLY" || rule.freq === "YEARLY") {
    var step = rule.freq === "MONTHLY" ? rule.interval : rule.interval * 12
    var byWeekday = rule.freq === "MONTHLY" && rule.byDay.length > 0 && rule.byDay[0].nth !== 0
    for (var k = 0; k < 1200; k++) {
      var y = first.getFullYear(), mo = first.getMonth() + k * step
      var dates = byWeekday
        ? rule.byDay.map(function(d) { return nthWeekday(new Date(y, mo, 1).getFullYear(), new Date(y, mo, 1).getMonth(), d.day, d.nth) })
                    .filter(function(n) { return n > 0 }).sort(function(a, b) { return a - b })
        : [first.getDate()]
      for (var j = 0; j < dates.length; j++) {
        var at = new Date(y, mo, dates[j], h, mi, se)
        // The 31st does not exist every month; such months are skipped.
        if (!byWeekday && at.getDate() !== first.getDate()) continue
        if (!offer(at.getTime())) return
      }
    }
    return
  }

  emit(ev.start)
}

// Occurrences overlapping [from, to), soonest first. All-day ones only when
// asked (the month view wants them, "next meeting" does not).
function between(events, from, to, withAllDay) {
  var out = []
  for (var i = 0; i < events.length; i++) {
    var ev = events[i]
    if (ev.allDay && !withAllDay) continue
    var length = ev.end - ev.start
    if (!ev.rule) {
      if (ev.end > from && ev.start < to) out.push(occurrence(ev, ev.start))
      continue
    }
    if (ev.start >= to) continue
    walk(ev, function(t) { if (t + length > from && t < to) out.push(occurrence(ev, t)) }, to)
  }
  return out.sort(function(a, b) { return a.start - b.start })
}

function dayKey(time) {
  var d = new Date(time)
  return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate()
}

// dayKey -> occurrences, for every day an occurrence touches.
function byDay(occurrences) {
  var map = {}
  occurrences.forEach(function(o) {
    var s = new Date(o.start)
    var day = new Date(s.getFullYear(), s.getMonth(), s.getDate())
    for (var n = 0; n < 62 && day.getTime() < o.end; n++) {
      var key = dayKey(day.getTime())
      ;(map[key] = map[key] || []).push(o)
      day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
    }
  })
  return map
}

// Google's public holiday calendars by ISO country code; `name` is what the
// country picker shows.
var HOLIDAYS = [
  { code: "IN", name: "India", id: "indian" },
  { code: "US", name: "United States", id: "usa" },
  { code: "GB", name: "United Kingdom", id: "uk" },
  { code: "CA", name: "Canada", id: "canadian" },
  { code: "AU", name: "Australia", id: "australian" },
  { code: "NZ", name: "New Zealand", id: "new_zealand" },
  { code: "IE", name: "Ireland", id: "irish" },
  { code: "DE", name: "Germany", id: "german" },
  { code: "FR", name: "France", id: "french" },
  { code: "ES", name: "Spain", id: "spain" },
  { code: "IT", name: "Italy", id: "italian" },
  { code: "NL", name: "Netherlands", id: "dutch" },
  { code: "JP", name: "Japan", id: "japanese" },
  { code: "KR", name: "South Korea", id: "south_korea" },
  { code: "SG", name: "Singapore", id: "singapore" },
  { code: "MY", name: "Malaysia", id: "malaysia" },
  { code: "ID", name: "Indonesia", id: "indonesian" },
  { code: "PH", name: "Philippines", id: "philippines" },
  { code: "AE", name: "UAE", id: "ae" },
  { code: "PK", name: "Pakistan", id: "pk" },
  { code: "BD", name: "Bangladesh", id: "bd" },
  { code: "LK", name: "Sri Lanka", id: "lk" },
  { code: "BR", name: "Brazil", id: "brazilian" },
  { code: "MX", name: "Mexico", id: "mexican" }
]

function holiday(code) {
  var c = String(code || "").toUpperCase()
  for (var i = 0; i < HOLIDAYS.length; i++)
    if (HOLIDAYS[i].code === c) return HOLIDAYS[i]
  return null
}

function holidayFeed(code) {
  var h = holiday(code)
  return h ? "https://calendar.google.com/calendar/ical/en." + h.id
    + "%23holiday%40group.v.calendar.google.com/public/basic.ics" : ""
}
