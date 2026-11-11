import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Config.js" as Config

// The island's settings: its entry in ~/.config/omarchy/shell.json, read
// live, with every value checked and defaulted here so the rest of the
// island can use them as they are.
Item {
  id: settings

  property string pluginId: ""
  // The shell's plugin API (for writing the entry back); null when absent.
  property var shell: null

  property var entry: ({})
  property var disabledPlugins: []
  property bool loaded: false

  function raw(key) {
    var v = entry ? entry[key] : undefined
    return v === undefined || v === null ? Config.DEFAULTS[key] : v
  }
  // Switches that are on unless set to false, and ones that are off unless true.
  function isOn(key) { return raw(key) !== false }
  function chosen(key) { return raw(key) === true }

  // ---- look
  readonly property bool notch: raw("style") !== "island"
  readonly property bool black: raw("background") === "black"
  readonly property bool idleHidden: raw("idle") === "hidden"
  readonly property string idleFace: Config.IDLE_FACES.indexOf(String(raw("idleFace"))) !== -1 ? String(raw("idleFace")) : "ticker"
  readonly property real zoom: Config.number(raw("scale"), 1, 0.6, 2)
  readonly property int topMargin: Math.round(Config.number(raw("topMargin"), 6, 0, 200))
  readonly property bool artworkTint: raw("visualizerColor") === "artwork"
  readonly property bool glow: chosen("glow")
  readonly property string textFont: String(raw("textFont"))
  readonly property string clockFormat: String(raw("clockFormat"))
  readonly property bool twelveHour: clockFormat.indexOf("AP") !== -1 || clockFormat.indexOf("ap") !== -1
  // A real display cutout to fit around (a MacBook notch), in pixels.
  readonly property var cutout: ({
    w: Config.number(raw("notchWidth"), 0, 0, 4000),
    h: Config.number(raw("notchHeight"), 0, 0, 400),
    r: Config.number(raw("notchRadius"), 0, 0, 400)
  })

  // ---- placement
  readonly property bool reserveSpace: isOn("reserveSpace")
  readonly property string monitor: String(raw("monitor"))
  readonly property bool overlayLayer: raw("layer") === "overlay"
  readonly property string keybind: raw("keybind") === false ? "" : String(raw("keybind")).trim()

  // ---- behaviour
  readonly property bool expandOnHover: chosen("expandOnHover")
  readonly property int mediaLingerMs: Math.round(Config.number(raw("mediaLingerSeconds"), 30, 0, 3600) * 1000)
  readonly property int calendarLeadMinutes: Math.round(Config.number(raw("calendarLeadMinutes"), 15, 1, 1440))
  readonly property var calendars: {
    var v = raw("calendars")
    return Array.isArray(v) ? v.map(String) : (v ? [String(v)] : [])
  }
  readonly property string holidays: String(raw("holidays"))

  // ---- what to show
  readonly property bool wantsNotifications: isOn("notifications")
  readonly property bool wantsOsd: isOn("osd")
  readonly property bool showInbox: isOn("inbox")
  readonly property bool showVolume: isOn("volume")
  readonly property bool showBrightness: isOn("brightness")
  readonly property bool showCharging: isOn("charging")
  readonly property bool showTrackChange: isOn("trackChange")
  readonly property bool showRecording: isOn("recording")
  readonly property bool showMic: isOn("mic")
  readonly property bool showCamera: isOn("camera")
  readonly property bool showCalendar: isOn("calendar")
  readonly property bool showBluetooth: isOn("bluetooth")
  readonly property bool timerSound: isOn("timerSound")

  // Merge `changes` into the entry and hand it to the shell, which owns
  // shell.json and writes it in one piece. The watcher below then picks the
  // new values up.
  function save(changes) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    var next = {}
    for (var key in entry) if (key !== "id") next[key] = entry[key]
    for (var change in changes) next[change] = changes[change]
    return shell.updateEntryInline(pluginId, next)
  }

  // Write every setting the entry lacks with its default. Values that are
  // there are never touched.
  function fillMissing() {
    if (!loaded || entry.id !== pluginId) return
    var keys = Config.missing(entry)
    if (keys.length === 0) return
    var changes = {}
    keys.forEach(function(key) { changes[key] = Config.DEFAULTS[key] })
    save(changes)
  }

  onShellChanged: fillMissing()
  onLoadedChanged: fillMissing()

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var config = Config.parse(text())
      if (config === null) return
      settings.entry = Config.entryFor(config, settings.pluginId)
      settings.disabledPlugins = Array.isArray(config.disabledPlugins) ? config.disabledPlugins.map(String) : []
      settings.loaded = true
    }
    onLoadFailed: {
      settings.entry = ({})
      settings.loaded = true
    }
  }
}
