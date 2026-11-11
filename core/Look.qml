import QtQuick
import Quickshell.Io
import qs.Commons

// Colours, fonts and measures, all from the Omarchy theme. Views read these
// rather than the theme directly, so the "background", "scale" and
// "textFont" settings apply everywhere at once.
QtObject {
  id: look

  property var settings: null
  // Device pixels per logical pixel on the island's screen (1.25 at 125%).
  property real devicePixelRatio: 1

  readonly property bool black: !!settings && settings.black
  readonly property real scaleFactor: settings ? settings.zoom : 1

  // The theme's own palette file, for the two tones the shell does not name:
  // color2 (green, for charging and success) and color3 (yellow/orange, for
  // warnings and privacy).
  property var palette: ({})

  readonly property color surface: black ? "#000000" : Color.background
  readonly property color fg: black ? "#f5f5f7" : Color.foreground
  readonly property color fgDim: Util.alpha(fg, 0.6)
  readonly property color fgFaint: Util.alpha(fg, 0.08)
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color green: palette.color2 || Color.accent
  readonly property color orange: palette.color3 || Color.urgent

  // The body is lit a little from above and deepens toward its lip, with a
  // hairline rim: obsidian, in the theme's own colours.
  readonly property color bodyTop: Qt.tint(surface, Util.alpha(Color.foreground, black ? 0.05 : 0.055))
  readonly property color bodyBottom: black ? "#000000" : Qt.darker(surface, 1.28)
  readonly property color rim: Util.alpha(Color.foreground, black ? 0.08 : 0.1)

  // The body colour `t` of the way down (0 = top, 1 = lip), for things that
  // must blend into it, such as the fades at the ends of scrolling text.
  function bodyAt(t) {
    var a = bodyTop, b = bodyBottom
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }

  // Numbers, times and glyphs in the theme's Nerd monospace; words in the
  // "textFont" setting ("theme" keeps everything in the theme font).
  readonly property string mono: Style.font.family
  readonly property string sans: !settings || settings.textFont === "theme" ? Style.font.family : settings.textFont

  // A length in the shell's spacing scale times the island's own scale.
  function s(px) { return Math.round(Style.space(px) * scaleFactor) }
  // A font size, likewise.
  function f(px) { return Math.max(6, Math.round(px * Style.fontScale * scaleFactor)) }
  // Snap a coordinate to the device pixel grid, so edges stay crisp.
  function snap(v) { return Math.round(v * devicePixelRatio) / devicePixelRatio }
  // Unscaled length per spacing unit, for turning text widths into sizes.
  readonly property real unit: Style.spacing.scale * scaleFactor

  // A colour by name, as scripts and toasts give them; "#rrggbb" passes.
  function tone(name) {
    var n = String(name || "").toLowerCase()
    if (n === "" || n === "accent") return accent
    if (n === "green" || n === "success") return green
    if (n === "orange" || n === "yellow" || n === "warning") return orange
    if (n === "red" || n === "urgent" || n === "error") return urgent
    if (n === "foreground" || n === "fg") return fg
    if (n === "dim") return fgDim
    return /^#[0-9a-f]{3,8}$/.test(n) ? n : accent
  }

  // Motion, from the shell: every duration goes through Style.duration so
  // "omarchy toggle animations" turns it off.
  readonly property bool still: Style.reduceMotion
  function ms(value) { return Style.duration(value) }
  readonly property var easeOut: Style.easeOut

  property FileView paletteFile: FileView {
    path: Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: {
      var found = {}
      var re = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"/gm
      var m
      while ((m = re.exec(String(text()))) !== null) found[m[1]] = m[2]
      look.palette = found
    }
  }

  property Connections themeWatch: Connections {
    target: Color
    function onBackgroundChanged() { look.paletteFile.reload() }
    function onAccentChanged() { look.paletteFile.reload() }
  }
}
