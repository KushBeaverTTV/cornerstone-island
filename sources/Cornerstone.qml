import QtQuick
import Quickshell
import Quickshell.Io

// Cornerstone dictation in the island (kushbeaverttv fork, 2026-11-11).
// Watches the status file omarchy-dictation-cornerstone writes and turns it
// into a live activity:
//   recording  -> "Listening" (red mic, running time); ✕ in the expanded
//                 island stops listening
//   processing -> "Transcribing"
//   then idle  -> a short "Typed N words" toast, or "Nothing heard"
//   error      -> a red "Dictation failed" toast
// Cornerstone's own recorder is left out of the generic mic indicator
// (IslandModel.isMicStream), so the two never show at once.
Item {
  id: cs

  property var island: null
  property var activities: null

  readonly property string dir: Quickshell.env("HOME") + "/.local/state/omarchy-dictation-cornerstone"
  readonly property string activityId: "cornerstone"
  readonly property string micGlyph: "󰍬"

  property string state: "idle"
  property real startedAt: 0
  property real processingAt: 0
  property string latestText: ""
  property bool typedThisRun: false
  property bool primed: false

  function clock(ms) {
    var s = Math.max(0, Math.floor(ms / 1000))
    var m = Math.floor(s / 60)
    s = s % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  function words(text) {
    var t = String(text || "").trim()
    return t.length === 0 ? 0 : t.split(/\s+/).length
  }

  function stop() {
    Quickshell.execDetached(["bash", "-lc", "omarchy-dictation-cornerstone stop"])
  }

  function setState(next) {
    if (next !== "idle" && next !== "recording" && next !== "processing" && next !== "error" && next !== "nokey") next = "idle"
    var prev = cs.state
    if (next === prev && primed) return
    cs.state = next
    // The first read only learns where things stand; no toast for history.
    if (!primed) {
      primed = true
      if (next !== "recording" && next !== "processing") return
    }
    if (!activities) return

    if (next === "recording") {
      startedAt = Date.now()
      activities.update(activityId, { title: "Listening", subtitle: "Cornerstone · ✕ stops listening",
                                      icon: micGlyph, color: "red", value: "0:00", ttl: 900 })
    } else if (next === "processing") {
      processingAt = Date.now()
      typedThisRun = false
      activities.update(activityId, { title: "Transcribing", subtitle: "Cornerstone", icon: micGlyph,
                                      color: "accent", value: "working", ttl: 300 })
    } else {
      activities.end(activityId, "")
      if (!island) return
      if (next === "error") {
        island.toast({ title: "Dictation failed", body: "Audio kept. Retry from the Cornerstone panel.", icon: "󰅚", color: "red", duration: 5000 })
      } else if (prev === "processing") {
        // last_text is written just before the status flips; give its
        // change event a moment to land before deciding what to say.
        doneTimer.restart()
      }
    }
  }

  FileView {
    id: statusFile
    path: cs.dir + "/status"
    watchChanges: true
    printErrors: false
    onLoaded: cs.setState(String(text()).trim())
    onFileChanged: reload()
  }

  FileView {
    id: lastText
    path: cs.dir + "/last_text"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var t = String(text()).trim()
      if (cs.primed && cs.state === "processing" && t !== cs.latestText) cs.typedThisRun = true
      cs.latestText = t
    }
  }

  Timer {
    id: doneTimer
    interval: 350
    onTriggered: {
      if (!cs.island) return
      var t = cs.latestText
      var n = cs.words(t)
      if (cs.typedThisRun && n > 0)
        cs.island.toast({ title: "Typed " + n + (n === 1 ? " word" : " words"), body: t.length > 70 ? t.slice(0, 70) + "…" : t,
                          icon: "󰄬", color: "green", duration: 2500 })
      else
        cs.island.toast({ title: "Nothing heard", body: "Cornerstone typed nothing.", icon: cs.micGlyph, color: "foreground", duration: 2000 })
    }
  }

  // Running time while listening.
  Timer {
    interval: 1000
    repeat: true
    running: cs.state === "recording"
    onTriggered: if (cs.activities) cs.activities.update(cs.activityId, { value: cs.clock(Date.now() - cs.startedAt) })
  }

  // A run that dies mid-way can leave "processing" behind; the dictation
  // script expires it after 5 minutes, so the island lets go then too.
  Timer {
    interval: 15000
    repeat: true
    running: cs.state === "processing"
    onTriggered: if (Date.now() - cs.processingAt > 300000) cs.setState("idle")
  }
}
