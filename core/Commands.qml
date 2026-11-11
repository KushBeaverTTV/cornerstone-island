import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Format.js" as Format
import "../lib/Notices.js" as Notices

// The island's IPC: `omarchy-shell dynamic-island <method> ...` for scripts
// and keybindings, and Omarchy's own `osd` target while the island owns the
// on-screen display (`omarchy osd` and every script that calls it).
Item {
  id: commands

  property var island: null
  readonly property var stage: island.stage

  function parseJson(text) {
    try { return { ok: true, value: JSON.parse(text || "{}") } } catch (e) { return { ok: false, value: null } }
  }

  IpcHandler {
    target: "dynamic-island"

    function expand(): string { commands.stage.expand(); return "ok" }
    function collapse(): string { commands.stage.collapse(); return "ok" }
    function toggle(): string { commands.stage.toggle(); return "ok" }

    // on | off | toggle: keep a strip free for the island at the top of the
    // screen, or let windows fill it.
    function reserveSpace(mode: string): string {
      if (["on", "off", "toggle"].indexOf(mode) === -1) return "usage: reserveSpace on|off|toggle"
      var next = mode === "toggle" ? !commands.island.settings.reserveSpace : mode === "on"
      commands.island.setReserveSpace(next)
      return next ? "on" : "off"
    }

    function toast(title: string, body: string, icon: string, color: string): string {
      commands.island.toast({ title: title, body: body, icon: icon, color: color })
      return "ok"
    }
    function show(payloadJson: string): string { commands.island.open(payloadJson); return "ok" }
    function demo(kind: string): string { return commands.island.demo.run(kind) }

    // "25m", "90s", "1h30m", "10:00", or plain minutes.
    function timer(duration: string, label: string): string {
      var seconds = Format.parseDuration(duration)
      if (seconds <= 0) return "bad duration: " + duration
      commands.island.clocks.startTimer(seconds, label)
      return "ok"
    }
    function timerToggle(): string { commands.island.clocks.toggleTimer(); return "ok" }
    function timerCancel(): string { commands.island.clocks.cancelTimer(); return "ok" }

    // start | pause | toggle | reset
    function stopwatch(action: string): string {
      var clocks = commands.island.clocks
      var a = String(action || "toggle")
      var flip = a === "toggle" || (a === "start" && !clocks.stopwatchRunning) || (a === "pause" && clocks.stopwatchRunning)
      if (a === "reset") clocks.resetStopwatch()
      else if (flip) clocks.toggleStopwatch()
      return "ok"
    }

    // A live activity for scripts; the payload is JSON (services/Activities.qml).
    function activity(id: string, payloadJson: string): string {
      var parsed = commands.parseJson(payloadJson)
      return parsed.ok ? commands.island.activities.upsert(id, parsed.value) : "bad json"
    }
    function endActivity(id: string, message: string): string { return commands.island.activities.end(id, message) }
    function activities(): string { return JSON.stringify(commands.island.activities.all) }

    function calendar(): string { commands.stage.openCalendar(); return "ok" }
    function refreshCalendar(): string { commands.island.calendar.refresh(); return "ok" }
    function addCalendar(link: string): string { commands.island.calendar.add(link); return "ok" }
    function removeCalendar(link: string): string { commands.island.calendar.remove(link); return "ok" }
    function addCalendarFromClipboard(): string { commands.island.pasteCalendar(); return "ok" }

    function state(): string { return JSON.stringify(commands.island.snapshot()) }
    function ping(): string { return "ok" }
  }

  // Omarchy's OSD. Volume already comes from PipeWire, so volume popups are
  // dropped unless there is no PipeWire sink; the rest become island HUDs.
  IpcHandler {
    target: "osd"
    enabled: commands.island.integration.servingOsd

    function show(payloadJson: string): string {
      var parsed = commands.parseJson(payloadJson)
      if (!parsed.ok) return "ok"
      var settings = commands.island.settings
      var hud = Notices.osdHud(parsed.value, { volume: settings.showVolume && !commands.island.sound.ready,
                                               brightness: settings.showBrightness })
      if (hud) {
        hud.tone = hud.dim ? "dim" : "fg"
        commands.island.hud.show(hud)
      }
      return "ok"
    }
    function close(): string { commands.island.hud.dismiss(["osd", "volume", "brightness"]); return "ok" }
    function state(): string { return commands.island.hud.current ? "open" : "closed" }
    function ping(): string { return "ok" }
  }
}
