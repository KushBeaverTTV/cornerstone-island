import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "chrome"
import "lib/Format.js" as Format

// Cornerstone Island: an Apple-style Dynamic Island for Omarchy.
//
// A keep-loaded panel plugin. The shell mounts it at start-up, and it draws
// its own strip across the top of one monitor.
//
// How it is put together:
//   core/      settings, look (theme and measures), the HUD queue, the stage
//              (what shows and how big), Omarchy integration, IPC, demos
//   services/  live sources: music, sound, power, backlight, recording,
//              microphone and camera, notifications, timer and stopwatch,
//              calendar, Bluetooth, script activities, Cornerstone dictation
//   views/     one file per thing the island can show
//   ui/        the small parts views are made of
//   chrome/    the window, the island's body, its status light and bubble
//   lib/       plain JavaScript: layout, formatting, calendar, players
//
// Data flows one way: services feed the stage, the stage picks a view and a
// size, the body eases to that size and the view fades in.
Item {
  id: island

  // Handed over by the shell.
  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "cornerstone.island"

  // Nothing announces itself for the first moments after a (re)load, so
  // the first readings of volume, brightness and battery pop no HUDs.
  property bool ready: false
  Timer { interval: 2500; running: true; onTriggered: island.ready = true }

  // A bead of light runs along the lip when something arrives.
  property int sweeps: 0
  function lipSweep() { sweeps++ }

  // ---- core
  readonly property alias settings: settingsCore
  readonly property alias look: lookCore
  readonly property alias hud: hudCore
  readonly property alias stage: stageCore
  readonly property alias integration: integrationCore
  readonly property alias demo: demoCore

  Settings { id: settingsCore; pluginId: island.pluginId; shell: island.shell }
  Look { id: lookCore; settings: settingsCore }
  Hud { id: hudCore }
  Stage { id: stageCore; island: island }
  Integration { id: integrationCore; island: island }
  Commands { island: island }
  Demo { id: demoCore; island: island }

  // ---- services
  readonly property alias media: mediaService
  readonly property alias sound: soundService
  readonly property alias power: powerService
  readonly property alias backlight: backlightService
  readonly property alias recorder: recorderService
  readonly property alias privacy: privacyService
  readonly property alias notices: noticesService
  readonly property alias clocks: clocksService
  readonly property alias calendar: calendarService
  readonly property alias activities: activitiesService
  readonly property alias dictation: dictationService
  readonly property alias glance: glanceService

  Media { id: mediaService; island: island }
  Sound { id: soundService; island: island }
  Power { id: powerService; island: island }
  Backlight { id: backlightService; island: island }
  Recorder { id: recorderService; island: island }
  Privacy { id: privacyService; island: island }
  Notices { id: noticesService; island: island; serving: integrationCore.servingNotifications }
  Clocks { id: clocksService; island: island }
  Calendar { id: calendarService; island: island }
  Activities { id: activitiesService; island: island }
  Dictation { id: dictationService; island: island }
  Bluetooth { island: island }
  Glance { id: glanceService; island: island }

  Connections {
    target: noticesService
    function onCurrentChanged() { if (noticesService.current) island.lipSweep() }
  }

  Surface { id: surface; island: island }

  // ---- actions shared by IPC and views

  // A message from a script: { title, body, icon, color, duration }.
  function toast(payload) {
    var p = payload || {}
    hud.show({
      layout: "toast",
      title: Format.clip(p.title, 120),
      body: Format.clip(p.body, 240),
      icon: Format.clip(p.icon, 8),
      tone: String(p.color || ""),
      duration: Number(p.duration) || 4000
    })
  }

  function setReserveSpace(on) {
    settings.save({ reserveSpace: on })
    hud.show({ key: "reserveSpace", layout: "label", label: on ? "Space kept for the island" : "Windows fill the top",
               icon: on ? "\u{f0294}" : "\u{f0293}", valueText: "", duration: 1600 })
  }

  function openLink(url) {
    var u = String(url || "")
    if (/^(https?|mailto):/i.test(u)) Quickshell.execDetached(["xdg-open", u])
    stage.collapse()
  }

  // "Paste" in the calendar: add whatever calendar link is on the clipboard
  // (only the first 4 KiB of it is read).
  Process {
    id: clipboard
    command: ["sh", "-c", "wl-paste --no-newline --type text 2>/dev/null | head -c 4096"]
    stdout: StdioCollector {
      onStreamFinished: {
        var link = String(text || "").trim().split(/\s+/)[0] || ""
        if (/^(https?|webcal):\/\//i.test(link) || /\.ics$/i.test(link)) {
          island.calendar.add(link)
          island.stage.calendarAdding = false
        } else {
          island.hud.show({ key: "calendar", layout: "label", label: "No calendar link copied", icon: "\u{f00ed}",
                            valueText: "", tone: "orange", duration: 2200 })
        }
      }
    }
  }

  function pasteCalendar() { if (!clipboard.running) clipboard.running = true }

  // ---- the shell's panel contract
  readonly property bool opened: stage.open

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    if (payload.title) toast(payload)
    else stage.expand()
  }
  function close() { stage.collapse() }
  function toggle() { stage.toggle() }

  // What `omarchy-shell dynamic-island state` reports.
  function snapshot() {
    return {
      view: stage.view,
      primary: stage.primary,
      secondary: stage.secondary,
      expanded: stage.open,
      hud: hud.current ? hud.current.layout : null,
      hudQueued: hud.queue.length,
      media: {
        has: media.present,
        playing: media.playing,
        title: media.title,
        artist: media.artist,
        cover: media.cover,
        appIcon: media.appIcon,
        canVolume: media.canVolume,
        volume: Math.round(media.sourceVolume * 100),
        muted: media.sourceMuted
      },
      recording: recorder.live,
      dictation: dictation.live ? dictation.phase : null,
      mic: privacy.micInUse,
      battery: power.present ? Math.round(power.level * 100) : null,
      brightness: backlight.level,
      timer: clocks.timerActive ? Math.ceil(clocks.timerLeft / 1000) : null,
      stopwatch: clocks.stopwatchActive ? Math.round(clocks.stopwatchElapsed / 100) / 10 : null,
      activity: activities.current ? activities.current.id : null,
      nextEvent: calendar.next ? calendar.next.title : null,
      camera: privacy.cameraInUse,
      outputs: sound.outputs.length,
      calendarTyping: stage.typing,
      calendar: {
        sources: calendar.sources.length,
        status: calendar.sources.map(function(l) { return calendar.statusOf(l) || "pending" }),
        upcoming: calendar.upcoming.length,
        justAdded: calendar.justAdded !== ""
      },
      notifications: {
        serving: integration.servingNotifications,
        omarchyDisabled: integration.omarchyNotificationsOff,
        showing: notices.current ? notices.current.summary : null,
        pending: notices.waiting,
        inbox: notices.inbox.length,
        dnd: notices.silenced
      },
      osd: integration.servingOsd,
      screen: surface.screen ? surface.screen.name : null
    }
  }
}
