import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Format.js" as Format

// Cornerstone dictation, as its own live activity.
//
// omarchy-dictation-cornerstone writes its state to a status file:
//   recording   "Listening", with a running time; the ✕ in the opened
//               island stops listening (and transcription starts)
//   processing  "Transcribing"
//   idle        after transcribing: a short "Typed N words" toast, or
//               "Nothing heard" when nothing was typed
//   error       a red "Dictation failed" toast
// Cornerstone's recorder (PipeWire node "cornerstone-dictation") is left out
// of the generic microphone indicator, so the two never show at once.
Item {
  id: dictation

  property var island: null

  readonly property string dir: Quickshell.env("HOME") + "/.local/state/omarchy-dictation-cornerstone"
  readonly property var phases: ["idle", "recording", "processing", "error", "nokey"]

  property string phase: "idle"
  property bool known: false          // the first read only learns where things stand
  property double startedAt: 0
  property double processingAt: 0
  property double now: Date.now()
  property bool typed: false          // last_text was written during this transcription
  property string lastText: ""
  // The ✕ while transcribing only puts the activity away; it comes back with
  // the next change.
  property bool putAway: false

  readonly property bool listening: phase === "recording"
  readonly property bool transcribing: phase === "processing"
  readonly property bool live: (listening || transcribing) && !putAway
  readonly property string elapsed: Format.clock((now - startedAt) / 1000)

  function stop() {
    if (listening) Quickshell.execDetached(["bash", "-lc", "omarchy-dictation-cornerstone stop"])
    else putAway = true
  }

  function setState(value) {
    var next = phases.indexOf(value) !== -1 ? value : "idle"
    var was = phase
    if (known && next === was) return
    phase = next
    putAway = false
    if (!known) {
      known = true
      if (next === "recording") startedAt = Date.now()
      if (next === "processing") processingAt = Date.now()
      return
    }
    if (next === "recording") {
      startedAt = Date.now()
      now = startedAt
    } else if (next === "processing") {
      processingAt = Date.now()
      typed = false
    } else if (next === "error") {
      island.hud.show({ layout: "toast", title: "Dictation failed", body: "Audio kept. Retry from the Cornerstone panel.",
                        icon: "\u{f015a}", tone: "urgent", duration: 5000 })
    } else if (next === "idle" && was === "processing") {
      // last_text is written just before the status flips; give its change
      // a moment to arrive before deciding what to say.
      outcome.restart()
    }
  }

  FileView {
    path: dictation.dir + "/status"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: dictation.setState(String(text()).trim())
  }

  FileView {
    path: dictation.dir + "/last_text"
    watchChanges: true
    printErrors: false
    // Any write counts, even of the same words as last time.
    onFileChanged: {
      if (dictation.transcribing) dictation.typed = true
      reload()
    }
    onLoaded: dictation.lastText = String(text()).trim()
  }

  Timer {
    id: outcome
    interval: 350
    onTriggered: {
      var words = Format.wordCount(dictation.lastText)
      if (dictation.typed && words > 0)
        dictation.island.hud.show({ layout: "toast", title: "Typed " + words + (words === 1 ? " word" : " words"),
                                    body: Format.clip(dictation.lastText, 70), icon: "\u{f012c}", tone: "green", duration: 2500 })
      else
        dictation.island.hud.show({ layout: "toast", title: "Nothing heard", body: "Cornerstone typed nothing.",
                                    icon: "\u{f036c}", tone: "fg", duration: 2000 })
    }
  }

  // The running time.
  Timer {
    interval: 250
    repeat: true
    running: dictation.listening
    onTriggered: dictation.now = Date.now()
  }

  // A run that dies midway can leave "processing" behind; the dictation
  // script gives up on it after five minutes, and so does the island.
  Timer {
    interval: 15000
    repeat: true
    running: dictation.transcribing
    onTriggered: if (Date.now() - dictation.processingAt > 300000) dictation.setState("idle")
  }
}
