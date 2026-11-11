import QtQuick
import Quickshell.Io
import "../lib/Glyphs.js" as Glyphs
import "../lib/Format.js" as Format

// Screen brightness, on machines with a backlight. sysfs sends no change
// events, so the one small file is read a few times a second.
Item {
  id: backlight

  property var island: null

  property string device: ""
  property int maximum: 0
  property real level: -1

  Process {
    running: true
    command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && echo \"$d\" && cat \"$d/max_brightness\" && break; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        if (lines.length < 2) return
        backlight.maximum = parseInt(lines[1], 10) || 0
        backlight.device = lines[0]
      }
    }
  }

  FileView {
    id: current
    path: backlight.device ? backlight.device + "/brightness" : ""
    blockLoading: true
  }

  Timer {
    interval: 350
    repeat: true
    running: backlight.device !== "" && backlight.maximum > 0 && backlight.island.settings.showBrightness
    onTriggered: {
      current.reload()
      var raw = parseInt(current.text(), 10)
      if (isNaN(raw)) return
      var next = Format.clamp01(raw / backlight.maximum)
      var before = backlight.level
      backlight.level = next
      if (before < 0 || Math.abs(next - before) < 0.001 || !backlight.island.ready) return
      backlight.island.hud.show({ key: "brightness", layout: "progress", icon: Glyphs.brightness(next),
                                  value: next, valueText: Math.round(next * 100) + "%", duration: 1500 })
    }
  }
}
