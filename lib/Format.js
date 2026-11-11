.pragma library

// Text the island builds out of numbers and times, and the cleaning of text
// that comes from elsewhere. Pure functions only: nothing here touches QML.

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function clamp01(v) {
  var n = Number(v)
  return isFinite(n) ? Math.min(1, Math.max(0, n)) : 0
}

// 272 -> "4:32", 4000 -> "1:06:40". `tenths` adds one decimal: "4:32.4".
function clock(seconds, tenths) {
  var total = Math.max(0, Number(seconds) || 0)
  var whole = Math.floor(total)
  var h = Math.floor(whole / 3600)
  var m = Math.floor(whole / 60) % 60
  var s = whole % 60
  var text = h > 0 ? h + ":" + pad2(m) + ":" + pad2(s) : m + ":" + pad2(s)
  if (tenths) text += "." + Math.floor((total - whole) * 10)
  return text
}

function percent(fraction) {
  return Math.round(clamp01(fraction) * 100) + "%"
}

// How far off something is: "now", "in 12m", "in 1h 5m".
function until(start, now) {
  var seconds = Math.round((Number(start) - Number(now)) / 1000)
  if (seconds <= 30) return "now"
  var minutes = Math.ceil(seconds / 60)
  if (minutes < 60) return "in " + minutes + "m"
  var rest = minutes % 60
  return "in " + Math.floor(minutes / 60) + "h" + (rest ? " " + rest + "m" : "")
}

// How long ago something arrived: "now", "5m", "2h", "3d".
function ago(time, now) {
  var seconds = Math.max(0, Math.floor((Number(now) - Number(time)) / 1000))
  if (seconds < 60) return "now"
  if (seconds < 3600) return Math.floor(seconds / 60) + "m"
  if (seconds < 86400) return Math.floor(seconds / 3600) + "h"
  return Math.floor(seconds / 86400) + "d"
}

// A duration as people type it, in seconds (0 when it makes no sense):
//   "25"      -> 25 minutes        "1:30"    -> 1 min 30 s
//   "1:30:00" -> 1 h 30 min        "1h30m", "90s", "2 hours", "1.5h"
var UNIT_SECONDS = { h: 3600, m: 60, s: 1 }

function parseDuration(text) {
  var t = String(text || "").trim().toLowerCase()
  if (t === "") return 0
  if (/^\d+$/.test(t)) return parseInt(t, 10) * 60
  if (/^\d+(:\d{1,2}){1,2}$/.test(t)) {
    var parts = t.split(":").map(Number)
    while (parts.length < 3) parts.unshift(0)
    return parts[0] * 3600 + parts[1] * 60 + parts[2]
  }
  var pattern = /(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)/g
  var total = 0
  var any = false
  var match
  while ((match = pattern.exec(t)) !== null) {
    any = true
    total += parseFloat(match[1]) * UNIT_SECONDS[match[2].charAt(0)]
  }
  // Anything left over that is not a number-unit pair means a typo, and a
  // typo must not quietly become a different timer.
  if (!any || t.replace(pattern, "").replace(/\band\b|[\s,.]+/g, "") !== "") return 0
  return Math.round(total)
}

function wordCount(text) {
  var t = String(text || "").trim()
  return t === "" ? 0 : t.split(/\s+/).length
}

// At most `max` characters, with an ellipsis when cut.
function clip(text, max) {
  var t = String(text || "")
  return t.length > max ? t.slice(0, Math.max(0, max - 1)).replace(/\s+$/, "") + "…" : t
}

// Notification bodies may carry a little markup. The island only ever shows
// plain text (every Text in it is PlainText as well), so tags go and the
// common entities are decoded once.
var ENTITIES = { "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&amp;": "&" }

function plain(value) {
  return String(value === undefined || value === null ? "" : value)
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&(lt|gt|quot|#39|apos|nbsp|amp);/g, function(e) { return ENTITIES[e] })
    .replace(/\s+/g, " ")
    .trim()
}
