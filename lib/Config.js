.pragma library

// The island's settings live in its own entry of shell.json's plugins list.

// Every setting and its default, in the order the README describes them.
// Settings missing from the entry are written in with these values, so they
// can be changed in place instead of looked up.
var DEFAULTS = {
  style: "notch",
  background: "theme",
  idle: "pill",
  idleFace: "ticker",
  scale: 1,
  topMargin: 6,
  reserveSpace: true,
  keybind: "SUPER + ALT + I",
  monitor: "primary",
  layer: "top",
  expandOnHover: false,
  clockFormat: "h:mm AP",
  mediaLingerSeconds: 30,
  notchWidth: 0,
  notchHeight: 0,
  notchRadius: 0,
  visualizerColor: "accent",
  textFont: "iA Writer Quattro V",
  glow: false,
  calendars: [],
  calendarLeadMinutes: 15,
  holidays: "auto",
  timerSound: true,
  bluetooth: true,
  camera: true,
  calendar: true,
  notifications: true,
  inbox: true,
  osd: true,
  volume: true,
  brightness: true,
  charging: true,
  trackChange: true,
  recording: true,
  mic: true
}

var IDLE_FACES = ["ticker", "clock", "lens", "none"]

// The parsed config, or null when the text is not a JSON object (for
// instance caught half-written), so a bad read is never mistaken for an
// empty config.
function parse(text) {
  try {
    var parsed = JSON.parse(String(text || ""))
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : null
  } catch (e) {
    return null
  }
}

function entryFor(config, pluginId) {
  var list = config && Array.isArray(config.plugins) ? config.plugins : []
  for (var i = 0; i < list.length; i++)
    if (list[i] && list[i].id === pluginId) return list[i]
  return {}
}

function missing(entry) {
  var e = entry || {}
  return Object.keys(DEFAULTS).filter(function(key) { return !(key in e) })
}

function number(value, fallback, min, max) {
  var n = Number(value)
  if (!isFinite(n)) n = fallback
  return Math.min(max, Math.max(min, n))
}

// "SUPER + ALT + I" -> { mask: Hyprland modifier mask, key: "I" }, or null.
var MODIFIER_BITS = { SHIFT: 1, CAPS: 2, CTRL: 4, CONTROL: 4, ALT: 8, MOD1: 8, MOD2: 16, MOD3: 32,
                      SUPER: 64, WIN: 64, LOGO: 64, MOD4: 64, MOD5: 128 }

function parseKeybind(text) {
  var parts = String(text || "").split("+").map(function(p) { return p.trim() }).filter(Boolean)
  if (parts.length === 0) return null
  var mask = 0
  for (var i = 0; i < parts.length - 1; i++) {
    var bit = MODIFIER_BITS[parts[i].toUpperCase()]
    if (bit === undefined) return null
    mask |= bit
  }
  return { mask: mask, key: parts[parts.length - 1] }
}
