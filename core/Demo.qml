import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Glyphs.js" as Glyphs

// Every state of the island on demand, without a player, a recording or a
// meeting: `omarchy-shell dynamic-island demo <kind>`, and `demo off` to go
// back to the real thing. Pretend notifications are never saved to the inbox.
Item {
  id: demo

  property var island: null

  readonly property string coverPath: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/demo-cover.png"
  property bool hasCover: false

  Process {
    running: true
    command: ["test", "-f", demo.coverPath]
    onExited: function(code) { demo.hasCover = code === 0 }
  }

  // A pretend song: a demo cover if one has been made, else the wallpaper.
  function song(playing) {
    var art = hasCover ? coverPath : Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    return { playing: playing, title: "Midnight City", artist: "M83", art: "file://" + art, length: 243 }
  }

  // Pretend sources; anything left out follows the real one.
  function pretend(parts) {
    var p = parts || {}
    island.media.stand = p.media
    island.media.position = p.position || 0
    island.media.quietly()
    island.recorder.stand = p.recording
    if (p.recording) island.recorder.elapsed = 42
    island.privacy.standMic = p.mic
    island.privacy.standCamera = p.camera
  }

  function level(kind) {
    var n = parseInt(String(kind).split(":")[1], 10)
    return isNaN(n) ? 0.62 : Math.max(0, Math.min(100, n)) / 100
  }

  function run(kind) {
    var hud = island.hud
    var stage = island.stage
    var k = String(kind || "")

    if (k === "off") {
      pretend({})
      hud.clear()
      stage.collapse()
      island.recorder.recheck()
      island.privacy.recheck()
      island.clocks.cancelTimer()
      island.clocks.resetStopwatch()
      island.activities.end("demo", "")
      island.notices.clearDemos()
      island.calendar.refresh()
    } else if (k === "media" || k === "paused") {
      pretend({ media: song(k === "media"), position: 71 })
    } else if (k === "expanded") {
      pretend({ media: song(true), position: 71 })
      stage.expand()
    } else if (k === "track") {
      pretend({ media: song(true) })
      hud.show({ key: "track", layout: "track", duration: 3200 })
    } else if (k === "outputs") {
      pretend({ media: song(true), position: 71 })
      stage.openOutputs()
    } else if (k === "recording") {
      pretend({ recording: true })
    } else if (k === "split") {
      pretend({ media: song(true), position: 71, recording: true })
    } else if (k === "recording-expanded") {
      pretend({ media: song(true), position: 71, recording: true })
      stage.expand()
    } else if (k === "idle-expanded") {
      pretend({ media: null, recording: false, mic: false })
      stage.expand()
    } else if (k === "mic") {
      pretend({ mic: true })
    } else if (k === "camera") {
      pretend({ camera: true })
    } else if (k === "volume" || k.indexOf("volume:") === 0) {
      var v = level(k)
      hud.show({ key: "volume", layout: "progress", icon: Glyphs.volume(v, false), value: v,
                 valueText: Math.round(v * 100) + "%", duration: 1600 })
    } else if (k === "brightness") {
      hud.show({ key: "brightness", layout: "progress", icon: Glyphs.brightness(0.8), value: 0.8, valueText: "80%", duration: 2500 })
    } else if (k === "charging") {
      island.lipSweep()
      hud.show({ key: "power", layout: "label", label: "Charging", icon: Glyphs.battery(0.8, true), valueText: "80%",
                 tone: "green", duration: 3000 })
    } else if (k === "lowbattery") {
      hud.show({ key: "power", layout: "label", label: "Low Battery", icon: Glyphs.battery(0.1, false), valueText: "10%",
                 tone: "urgent", duration: 3000 })
    } else if (k === "device") {
      hud.show({ key: "device", layout: "label", label: "WH-1000XM5", icon: Glyphs.device("audio-headset"),
                 valueText: "82%", tone: "green", duration: 3000 })
    } else if (k === "toast") {
      island.toast({ title: "Build finished", body: "cornerstone-island · 0 errors", icon: Glyphs.CHECK, color: "green" })
    } else if (k === "notification" || k === "notification-actions") {
      island.notices.pretend({
        app: "Slack", appIcon: "slack", summary: "Design review",
        body: "Can you share the island screenshots before standup?",
        actions: k === "notification-actions" ? [{ id: "reply", text: "Reply" }, { id: "read", text: "Mark as Read" }] : []
      })
    } else if (k === "inbox") {
      [
        { app: "Slack", appIcon: "slack", summary: "Design review", body: "Can you share the island screenshots?" },
        { app: "Chromium", appIcon: "chromium", summary: "GitHub", body: "Pull request #42 was merged" },
        { app: "omarchy-update", glyph: Glyphs.UPDATE, summary: "Update available", body: "Omarchy 4.0.5 is ready to install" }
      ].forEach(function(fields) { island.notices.retire(island.notices.pretend(fields)) })
      stage.openInbox()
    } else if (k === "timer") {
      island.clocks.startTimer(272, "Tea")
    } else if (k === "stopwatch") {
      island.clocks.resetStopwatch()
      island.clocks.toggleStopwatch()
    } else if (k === "activity") {
      island.activities.upsert("demo", { title: "Building cornerstone-island", subtitle: "Compiling views · 14 of 22",
                                         icon: Glyphs.PACKAGE, progress: 0.64, color: "green", ttl: 60 })
    } else if (k === "calendar") {
      island.calendar.demo()
    } else if (k === "calendar-view") {
      island.calendar.demo()
      stage.openCalendar()
    } else {
      return "unknown demo: " + k
    }
    return "ok"
  }
}
