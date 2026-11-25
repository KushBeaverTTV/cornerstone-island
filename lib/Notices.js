.pragma library

.import "Format.js" as Format
.import "Glyphs.js" as Glyphs

// Helpers for the notification service and for Omarchy's OSD requests.

// Senders whose messages are feedback, not news (Omarchy's own rule): they
// never wait in the inbox.
function isFeedback(appName) {
  var name = String(appName || "")
  return name === "notify-send" || name === "omarchy-action"
}

// Omarchy's rule for what still shows while silenced: its own action
// toasts, and a bare `notify-send` that is critical.
function breaksSilence(entry) {
  return entry.app === "omarchy-action" || (entry.app === "notify-send" && entry.critical)
}

// How long a banner stays, iOS short. Critical ones stay until handled; a
// sender's own longer timeout is honoured up to 30 seconds.
function bannerMs(entry) {
  if (!entry || entry.critical) return 0
  var base = entry.low ? 4000 : 6000
  return Math.min(30000, Math.max(base, entry.timeout > 0 ? entry.timeout : 0))
}

function hint(hints, name) {
  try {
    var value = hints ? hints[name] : undefined
    return value === undefined || value === null ? "" : String(value)
  } catch (e) {
    return ""
  }
}

// omarchy-notification-send --exec hands the click command over as a JSON
// argv. Anything other than a non-empty list of strings is ignored.
function execArgv(text) {
  var parsed
  try { parsed = JSON.parse(String(text || "")) } catch (e) { return null }
  if (!Array.isArray(parsed) || parsed.length === 0) return null
  return parsed.every(function(a) { return typeof a === "string" }) ? parsed : null
}

// A plain record of a notification, safe to keep after its sender is gone
// and to write to disk. Text is cleaned of markup and capped in length.
function record(fields, key, time) {
  var f = fields || {}
  return {
    key: key,
    app: Format.clip(f.app, 80),
    appIcon: String(f.appIcon || ""),
    desktopEntry: String(f.desktopEntry || ""),
    summary: Format.clip(Format.plain(f.summary), 300),
    body: Format.clip(Format.plain(f.body), 1000),
    image: String(f.image || ""),
    glyph: Format.clip(f.glyph, 4),
    execArgv: String(f.execArgv || ""),
    critical: f.critical === true,
    low: f.low === true,
    timeout: Number(f.timeout) || 0,
    actions: Array.isArray(f.actions) ? f.actions.slice(0, 3) : [],
    time: Number(f.time) || time
  }
}

// Fields worth saving for the inbox file: no live object, no temporary
// images (they will be gone after a restart).
function persistable(entry) {
  var image = entry.image && entry.image.indexOf("/tmp/") === -1 && entry.image.indexOf("image://") !== 0 ? entry.image : ""
  return {
    app: entry.app, appIcon: entry.appIcon, desktopEntry: entry.desktopEntry, summary: entry.summary,
    body: entry.body, image: image, glyph: entry.glyph, execArgv: entry.execArgv,
    critical: entry.critical, time: entry.time
  }
}

// Slugify a display name into a freedesktop icon-name guess:
// "Google Chrome" -> "google-chrome".
function iconSlug(name) {
  return String(name || "").slice(0, 256).toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^[-.]+|[-.]+$/g, "")
    .slice(0, 100)
}

// Known app-name -> icon-name aliases for apps whose notifications omit
// appIcon/desktopEntry or use a friendly name that differs from their icon.
var ICON_ALIASES = {
  "cornerstone": ["cornerstone-hq", "cornerstone"],
  "google chrome": ["google-chrome"],
  "brave": ["brave-browser", "brave"],
  "youtube music": ["chrome-cinhimbnkkaeohfgghhklpknlkffjgod-Default", "youtube-music", "youtube"],
  "code": ["visual-studio-code", "code"],
  "visual studio code": ["visual-studio-code", "code"]
}

// Ordered, deduplicated theme icon names and desktop-entry lookup names for
// a notification record. Never touches the filesystem; Services/Notices.qml
// resolves these through Quickshell.iconPath and DesktopEntries.
function iconCandidates(entry) {
  if (!entry) return { themed: [], entries: [] }
  var themed = []
  var entries = []
  function addThemed(name) {
    var n = String(name || "").trim()
    if (!n) return
    if (/^[A-Za-z0-9_][A-Za-z0-9_.-]{0,255}$/.test(n) && themed.indexOf(n) === -1) themed.push(n)
    var s = iconSlug(n)
    if (s && /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,255}$/.test(s) && themed.indexOf(s) === -1) themed.push(s)
  }
  function addEntry(name) {
    var n = String(name || "").trim()
    if (n && entries.indexOf(n) === -1) entries.push(n)
  }

  var appIcon = String(entry.appIcon || "")
  if (appIcon.indexOf("image://icon/") === 0) appIcon = appIcon.slice(13)
  var desktopEntry = String(entry.desktopEntry || "")
  var app = String(entry.app || "")

  if (appIcon && appIcon.indexOf("://") === -1 && appIcon.charAt(0) !== "/") addThemed(appIcon)
  addThemed(desktopEntry)
  addThemed(app)
  var alias = ICON_ALIASES[app.toLowerCase()]
  if (alias) {
    for (var i = 0; i < alias.length; i++) { addThemed(alias[i]); addEntry(alias[i]) }
  }
  addEntry(desktopEntry)
  addEntry(appIcon)
  addEntry(app)
  return { themed: themed, entries: entries }
}

// A one-colour freedesktop symbolic icon (black SVG that needs tinting on
// dark surfaces).
function isSymbolicIcon(source) {
  var s = String(source || "").split("?")[0]
  return /-symbolic$/.test(s) || s.indexOf("/symbolic/") !== -1 || /-symbolic\.[A-Za-z]+$/.test(s)
}

// Whether a URL points to an app/theme icon (drawn whole with PreserveAspectFit)
// rather than a photo or album cover (cropped cleanly into a rounded tile).
function isIconSource(source) {
  var s = String(source || "").split("?")[0].toLowerCase()
  if (s.indexOf("image://icon/") === 0) return true
  if (s.indexOf("/icons/") !== -1 || s.indexOf("/pixmaps/") !== -1) return true
  return /\.svg$/.test(s)
}

// Omarchy's OSD payload ({ icon, message, value, max, duration }, as sent by
// `omarchy osd` and its callers) as an island HUD, or null to drop it.
// `show` says whether levels may appear: { volume, brightness }.
function osdHud(payload, show) {
  var p = payload || {}
  var icon = String(p.icon || "").toLowerCase()
  var message = Format.clip(p.message, 120)
  var isVolume = icon.indexOf("volume") === 0 || icon === "muted" || icon === "mute"
  var isOff = /muted|-off$|^mute$/.test(icon) || / disabled$/i.test(message)
  var requested = parseInt(p.duration, 10)
  var duration = isNaN(requested) ? 1500 : Math.min(10000, Math.max(1500, requested))
  var raw = parseInt(p.value, 10)

  if (message === "" && p.value !== undefined && p.value !== "" && !isNaN(raw)) {
    if (isVolume && !show.volume) return null
    if (icon === "brightness" && !show.brightness) return null
    var level = Format.clamp01(raw / Math.max(1, parseInt(p.max || "100", 10) || 100))
    return {
      key: isVolume ? "volume" : (icon === "brightness" ? "brightness" : "osd"),
      layout: "progress",
      icon: isVolume ? Glyphs.volume(level, isOff) : (icon === "brightness" ? Glyphs.brightness(level) : Glyphs.osd(p.icon)),
      value: level,
      valueText: Math.round(level * 100) + "%",
      dim: isOff,
      duration: duration
    }
  }
  if (message === "" && !p.icon) return null
  return {
    key: "osd",
    layout: "label",
    label: message,
    // Switching outputs sends the device's name with a volume icon.
    valueText: isVolume && !isOff && message !== "" ? "Playing on" : "",
    icon: Glyphs.osd(p.icon),
    dim: isOff,
    duration: duration
  }
}
