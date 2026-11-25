.pragma library

// What the island shows and how big it is.
//
// Live activities compete for the pill by rank; the winner owns the pill and
// the runner-up rides in the bubble beside it. Transient things (a HUD, a
// notification banner) cover the pill for a moment; an island the user
// opened shows the opened form of whatever it was about.

// Highest rank first.
var LIVE_RANK = ["recording", "dictation", "timer", "activity", "media", "stopwatch", "calendar", "mic", "inbox"]

// `flags` maps an activity name to whether it is live; the result is the
// live ones by rank.
function rankLive(flags) {
  return LIVE_RANK.filter(function(name) { return !!flags[name] })
}

// The opened form of each activity.
var OPENS_INTO = {
  timer: "clock-expanded",
  stopwatch: "clock-expanded",
  activity: "activity-expanded",
  calendar: "calendar-expanded",
  dictation: "dictation-expanded",
  media: "media-expanded"
}

var HUD_VIEWS = { progress: "hud-progress", label: "hud-label", track: "hud-track", toast: "hud-toast" }

// s: { open, panel ("inbox" | "outputs" | "calendar" | ""), focus, live[],
//      hasMedia, hud, banner, bannerActions, idleHidden, hovered }
function chooseView(s) {
  if (s.open) {
    if (s.panel) return s.panel + "-expanded"
    // A recording takes the top of an opened island so it can be stopped
    // there; music, if any, rides along underneath.
    if (s.live.indexOf("recording") !== -1) return s.hasMedia ? "recording-media-expanded" : "recording-expanded"
    var focus = s.focus || s.live[0] || ""
    if (focus === "media" && !s.hasMedia) focus = ""
    return OPENS_INTO[focus] || (s.hasMedia ? "media-expanded" : "idle-expanded")
  }
  // A level (volume, brightness) answers a key press, so it shows at once,
  // even over a banner.
  if (s.hud && s.hud.layout === "progress") return HUD_VIEWS.progress
  if (s.banner) return s.bannerActions ? "notification-actions" : "notification"
  if (s.hud) return HUD_VIEWS[s.hud.layout] || HUD_VIEWS.label
  if (s.live.length > 0) return s.live[0]
  if (s.idleHidden) return "hidden"
  return s.hovered ? "idle-hover" : "idle"
}

// Base size of each view in unscaled pixels: [width, height, corner radius].
// The compact views are true capsules (radius = height / 2).
var SHAPES = {
  "idle": [126, 32, 16],
  "idle-hover": [138, 34, 17],
  "hidden": [0, 32, 16],
  "media": [300, 32, 16],
  "recording": [232, 32, 16],
  "dictation": [256, 32, 16],
  "mic": [214, 32, 16],
  "inbox": [200, 32, 16],
  "timer": [236, 32, 16],
  "stopwatch": [236, 32, 16],
  "activity": [256, 32, 16],
  "calendar": [300, 32, 16],
  "hud-progress": [310, 36, 18],
  "hud-label": [310, 36, 18],
  "hud-track": [368, 66, 28],
  "hud-toast": [368, 66, 28],
  "notification": [404, 78, 34],
  "notification-actions": [404, 118, 38],
  "media-expanded": [404, 218, 42],
  "recording-expanded": [392, 76, 34],
  "recording-media-expanded": [404, 145, 40],
  "dictation-expanded": [392, 96, 36],
  "idle-expanded": [424, 150, 40],
  "clock-expanded": [380, 132, 40],
  "activity-expanded": [392, 104, 38],
  "calendar-expanded": [500, 262, 40]
}

// Views that sit on the notch itself, and so must clear a real camera
// cutout when one is configured.
var ON_THE_NOTCH = ["idle", "idle-hover", "media", "recording", "dictation", "mic", "inbox",
                    "timer", "stopwatch", "activity", "calendar"]

function isCompact(view) {
  return ON_THE_NOTCH.indexOf(view) !== -1
}

// Every view the island can draw.
var VIEWS = Object.keys(SHAPES).concat(["inbox-expanded", "outputs-expanded"])

// The opened inbox grows by rows (up to four, then it scrolls).
var INBOX_ROW = 58
var INBOX_GAP = 6

function inboxShape(count) {
  if (count <= 0) return [420, 72, 32]
  var rows = Math.min(4, count)
  return [420, 14 + rows * INBOX_ROW + (rows - 1) * INBOX_GAP + 54, 36]
}

// The output picker: a header and one row per output (up to six).
var OUTPUT_ROW = 40
var OUTPUT_GAP = 4

function outputsShape(count) {
  var rows = Math.max(1, Math.min(6, count))
  return [392, 62 + rows * OUTPUT_ROW + (rows - 1) * OUTPUT_GAP, 36]
}

// { w, h, r } for a view. `counts` holds { inbox, outputs } for the views
// that grow with their contents; `cutout` is a measured display notch
// { w, h, r } (zeros when there is none).
function shape(view, counts, cutout) {
  var base = view === "inbox-expanded" ? inboxShape(counts && counts.inbox || 0)
    : view === "outputs-expanded" ? outputsShape(counts && counts.outputs || 0)
    : (SHAPES[view] || SHAPES.idle)
  var size = { w: base[0], h: base[1], r: base[2] }
  if (!cutout || !(cutout.w > 0) || !isCompact(view)) return size
  // Over a real cutout: at least as tall as it, and wide enough to leave
  // 60 px of content either side (the resting pill just covers it).
  var h = Math.max(size.h, cutout.h > 0 ? cutout.h : size.h)
  if (view === "idle" || view === "idle-hover") {
    var r = cutout.r > 0 ? cutout.r : h / 2
    return { w: cutout.w + (view === "idle-hover" ? 12 : 0), h: h, r: Math.min(r, h / 2) }
  }
  return { w: Math.max(size.w, cutout.w + 120), h: h, r: h / 2 }
}
