.pragma library

// Nerd Font glyphs the island draws, and the rules that pick them.

var MIC = "\u{f036c}"
var MIC_OFF = "\u{f036d}"
var CAMERA = "\u{f0100}"
var BELL = "\u{f009a}"
var BELL_OFF = "\u{f009b}"
var CALENDAR = "\u{f00ed}"
var CALENDAR_ALERT = "\u{f00ee}"
var TIMER = "\u{f051b}"
var STOPWATCH = "\u{f13ab}"
var ALARM = "\u{f0020}"
var CHECK = "\u{f012c}"
var CLOSE = "\u{f0156}"
var STOP = "\u{f04db}"
var PLAY = "\u{f040a}"
var PAUSE = "\u{f03e4}"
var PREVIOUS = "\u{f04ae}"
var NEXT = "\u{f04ad}"
var MUSIC = "\u{f075a}"
var PLUS = "\u{f0415}"
var BACK = "\u{f004d}"
var CHEVRON_LEFT = "\u{f0141}"
var CHEVRON_RIGHT = "\u{f0142}"
var OPEN_LINK = "\u{f03cc}"
var PASTE = "\u{f0192}"
var ERROR = "\u{f015a}"
var WARNING = "\u{f0026}"
var BLUETOOTH = "\u{f00b1}"
var BLUETOOTH_OFF = "\u{f00b2}"
var PACKAGE = "\u{f03d7}"
var SPACE_KEPT = "\u{f0294}"
var SPACE_FREE = "\u{f0293}"
var SPARKLE = "✦"

function volume(level, muted) {
  if (muted || level <= 0.001) return "\u{f075f}"
  if (level < 0.34) return "\u{f057f}"
  if (level < 0.67) return "\u{f0580}"
  return "\u{f057e}"
}

function brightness(level) {
  if (level < 0.34) return "\u{f00de}"
  if (level < 0.67) return "\u{f00df}"
  return "\u{f00e0}"
}

// Eleven steps from empty to full, draining and charging.
var BATTERY_DRAINING = ["\u{f008e}", "\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}",
                        "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0079}"]
var BATTERY_CHARGING = ["\u{f089f}", "\u{f089c}", "\u{f0086}", "\u{f0087}", "\u{f0088}", "\u{f089d}",
                        "\u{f0089}", "\u{f089e}", "\u{f008a}", "\u{f008b}", "\u{f0085}"]

function battery(fraction, charging) {
  var step = Math.round(Math.min(1, Math.max(0, Number(fraction) || 0)) * 10)
  return (charging ? BATTERY_CHARGING : BATTERY_DRAINING)[step]
}

// First rule whose word appears in `text` wins.
function firstMatch(text, rules, fallback) {
  var t = String(text || "").toLowerCase()
  for (var i = 0; i < rules.length; i++)
    for (var j = 0; j < rules[i][0].length; j++)
      if (t.indexOf(rules[i][0][j]) !== -1) return rules[i][1]
  return fallback
}

var HEADPHONES = "\u{f02cb}"
var SPEAKER = "\u{f04c3}"
var SCREEN_AUDIO = "\u{f0841}"

// A Bluetooth device from its freedesktop icon name.
function device(icon) {
  return firstMatch(icon, [
    [["headset", "headphone"], HEADPHONES],
    [["speaker", "audio"], SPEAKER],
    [["keyboard"], "\u{f030c}"],
    [["mouse", "tablet"], "\u{f037d}"],
    [["gaming", "joystick"], "\u{f02b4}"],
    [["phone"], "\u{f011c}"],
    [["watch"], "\u{f0589}"],
    [["computer"], "\u{f0322}"]
  ], "\u{f00b1}")
}

// An audio output from its PipeWire node name and description.
function output(node) {
  if (!node) return SPEAKER
  return firstMatch(String(node.name || "") + " " + String(node.description || ""), [
    [["bluez", "headphone", "headset"], HEADPHONES],
    [["hdmi", "displayport"], SCREEN_AUDIO]
  ], SPEAKER)
}

// Omarchy's OSD names its icons ("microphone-muted", "keyboard", ...); a
// name the island does not know is passed through, so a caller can also
// send a glyph directly.
function osd(name) {
  var n = String(name || "").toLowerCase()
  if (/^(microphone-muted|microphone-off|mic-muted|mic-off)/.test(n)) return MIC_OFF
  if (n === "microphone" || n === "mic") return MIC
  if (n === "keyboard") return "\u{f030c}"
  if (n === "brightness" || n === "display") return brightness(1)
  if (n === "touchpad") return "\u{f07f8}"
  if (n === "touch" || n === "touchscreen") return "\u{f0741}"
  if (n === "reboot" || n === "restart") return "\u{f0709}"
  if (n === "shutdown" || n === "power" || n === "poweroff") return "\u{f0425}"
  if (n === "logout" || n === "sign-out" || n === "leave") return "\u{f0343}"
  if (/^(media|player)/.test(n)) return MUSIC
  if (/^(volume-muted|volume-mute|muted|mute)$/.test(n)) return volume(0, true)
  if (n.indexOf("volume") === 0) return volume(1, false)
  return String(name || "")
}
