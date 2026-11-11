import QtQuick
import Quickshell
import Quickshell.Io

// The timer and the stopwatch. Both are kept as wall-clock times in a small
// state file, so they carry on across shell restarts, and a timer that ran
// out while the shell was down still rings when it comes back.
Item {
  id: clocks

  property var island: null

  property double now: Date.now()

  // ---- timer: running until `timerEnd`, or paused with `timerLeftPaused`
  property double timerEnd: 0
  property double timerLeftPaused: 0
  property double timerTotal: 0
  property bool timerPaused: false
  property string timerLabel: ""

  readonly property bool timerActive: timerEnd > 0 || timerPaused
  readonly property double timerLeft: timerPaused ? timerLeftPaused : Math.max(0, timerEnd - now)
  // How much of it is gone, 0..1.
  readonly property real timerProgress: timerTotal > 0 ? Math.min(1, Math.max(0, 1 - timerLeft / timerTotal)) : 0

  // ---- stopwatch: earlier runs banked, plus the current run
  property double stopwatchStart: 0
  property double stopwatchBanked: 0
  property bool stopwatchRunning: false

  readonly property bool stopwatchActive: stopwatchRunning || stopwatchBanked > 0
  readonly property double stopwatchElapsed: stopwatchBanked + (stopwatchRunning ? now - stopwatchStart : 0)

  Timer {
    // Tenths show on the opened stopwatch, so it ticks faster while running.
    interval: clocks.stopwatchRunning ? 100 : 250
    repeat: true
    running: (clocks.timerActive && !clocks.timerPaused) || clocks.stopwatchRunning
    onTriggered: {
      clocks.now = Date.now()
      if (clocks.timerActive && !clocks.timerPaused && clocks.timerEnd <= clocks.now) clocks.ring()
    }
  }

  function startTimer(seconds, label) {
    now = Date.now()
    timerTotal = Math.max(1, Number(seconds) || 0) * 1000
    timerEnd = now + timerTotal
    timerPaused = false
    timerLeftPaused = 0
    timerLabel = String(label || "").slice(0, 60)
    save()
  }

  function toggleTimer() {
    if (!timerActive) return
    now = Date.now()
    if (timerPaused) {
      timerEnd = now + timerLeftPaused
      timerPaused = false
    } else {
      timerLeftPaused = Math.max(0, timerEnd - now)
      timerEnd = 0
      timerPaused = true
    }
    save()
  }

  function addMinute() {
    if (!timerActive) return
    if (timerPaused) timerLeftPaused += 60000
    else timerEnd += 60000
    timerTotal += 60000
    save()
  }

  function cancelTimer() {
    timerEnd = 0
    timerPaused = false
    timerLeftPaused = 0
    timerTotal = 0
    timerLabel = ""
    save()
  }

  function ring() {
    var label = timerLabel
    cancelTimer()
    island.hud.show({ layout: "toast", title: label || "Timer", body: "Time's up", icon: "\u{f0020}",
                      tone: "accent", duration: 12000 })
    if (island.settings.timerSound)
      Quickshell.execDetached(["sh", "-c",
        "s=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; " +
        "for i in 1 2 3; do pw-play \"$s\" 2>/dev/null || paplay \"$s\" 2>/dev/null; done"])
  }

  function toggleStopwatch() {
    now = Date.now()
    if (stopwatchRunning) {
      stopwatchBanked += now - stopwatchStart
      stopwatchRunning = false
    } else {
      stopwatchStart = now
      stopwatchRunning = true
    }
    save()
  }

  function resetStopwatch() {
    stopwatchRunning = false
    stopwatchBanked = 0
    stopwatchStart = 0
    save()
  }

  // ---- state file
  property bool restored: false
  readonly property var savedFields: ["timerEnd", "timerLeftPaused", "timerTotal", "timerPaused", "timerLabel",
                                      "stopwatchStart", "stopwatchBanked", "stopwatchRunning"]

  function save() {
    if (!restored) return
    var state = {}
    savedFields.forEach(function(field) { state[field] = clocks[field] })
    stateFile.setText(JSON.stringify(state) + "\n")
  }

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/clocks.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      if (clocks.restored) return
      var s = {}
      try { s = JSON.parse(text() || "{}") || {} } catch (e) {}
      clocks.now = Date.now()
      clocks.timerEnd = Number(s.timerEnd) || 0
      clocks.timerLeftPaused = Number(s.timerLeftPaused) || 0
      clocks.timerTotal = Number(s.timerTotal) || 0
      clocks.timerPaused = s.timerPaused === true
      clocks.timerLabel = String(s.timerLabel || "")
      clocks.stopwatchStart = Number(s.stopwatchStart) || 0
      clocks.stopwatchBanked = Number(s.stopwatchBanked) || 0
      clocks.stopwatchRunning = s.stopwatchRunning === true
      clocks.restored = true
      // Ran out while the shell was down: ring now.
      if (clocks.timerEnd > 0 && !clocks.timerPaused && clocks.timerEnd <= clocks.now) clocks.ring()
    }
    onLoadFailed: clocks.restored = true
  }
}
