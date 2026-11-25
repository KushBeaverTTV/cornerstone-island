import QtQuick
import Quickshell
import Quickshell.Io

// Cornerstone Jarvis: hands-free voice & quick-ask bridge to the default agent (agy).
// Watches ~/.local/state/cornerstone-jarvis/state.json updated atomically by
// cornerstone-jarvis.service and dispatches commands via the cornerstone-jarvis CLI.
Item {
  id: jarvis

  property var island: null

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/cornerstone-jarvis/state.json"

  property string phase: "idle"
  property bool wakeEnabled: true
  property bool wakeGated: false
  property string wakeGateReason: ""
  property bool ttsEnabled: true
  property string conversationId: ""
  property string prompt: ""
  property string statusLine: ""
  property string reply: ""
  property string error: ""
  property double startedAt: 0
  property double updatedAt: 0
  property real level: 0
  property int turnCount: 0
  property bool wakeReady: false
  property bool ttsReady: false
  property double now: Date.now()
  property bool known: false
  property bool daemonAvailable: false

  readonly property bool listening: phase === "listening"
  readonly property bool transcribing: phase === "transcribing"
  readonly property bool thinking: phase === "thinking"
  readonly property bool speaking: phase === "speaking"
  readonly property bool busy: listening || transcribing || thinking || speaking
  readonly property bool live: busy
  readonly property bool hasReply: reply !== ""
  readonly property bool hasError: phase === "error" && error !== ""

  readonly property string elapsed: {
    if (!startedAt) return "0:00"
    var s = Math.max(0, Math.floor((now - startedAt * 1000) / 1000))
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : String(r))
  }

  signal replyArrived()

  function runCli(args) {
    Quickshell.execDetached(["cornerstone-jarvis"].concat(args))
  }

  function listen() { runCli(["listen"]) }
  function ask(text) {
    var t = String(text || "").trim()
    if (!t) return
    runCli(["ask", t])
  }
  function stop() { runCli(["stop"]) }
  function reset() { runCli(["reset"]) }
  function toggleWake() { runCli(["wake", "toggle"]) }
  function setWake(mode) { runCli(["wake", mode || "toggle"]) }
  function toggleTts() { runCli(["tts", "toggle"]) }
  function setTts(mode) { runCli(["tts", mode || "toggle"]) }

  // Clicking the always-on Jarvis mic orb beside the island:
  // - idle / reply / error -> start listening immediately
  // - listening            -> stop listening & submit
  // - thinking / speaking  -> open the Jarvis card so you can read / stop / follow up
  function orbClick() {
    if (listening || phase === "idle" || phase === "reply" || phase === "error") {
      listen()
    } else if (island && island.stage) {
      island.stage.openJarvis(false)
    }
  }

  function popOut() {
    var work = Quickshell.env("HOME") + "/Work"
    var cid = String(conversationId || "").trim()
    if (cid !== "" && /^[a-zA-Z0-9_-]+$/.test(cid)) {
      Quickshell.execDetached(["omarchy-launch-tui", "sh", "-c",
        'cd "$1" 2>/dev/null || true; exec agy --dangerously-skip-permissions --resume "$2"',
        "sh", work, cid])
    } else {
      Quickshell.execDetached(["omarchy-launch-tui", "sh", "-c",
        'cd "$1" 2>/dev/null || true; exec agy --dangerously-skip-permissions',
        "sh", work])
    }
    if (island && island.stage) island.stage.collapse()
  }

  function applyState(raw) {
    var data = null
    try { data = JSON.parse(String(raw || "")) } catch (e) { return }
    if (!data || typeof data !== "object") return
    daemonAvailable = true
    var prevPhase = phase
    var prevTurn = turnCount
    var nextPhase = String(data.phase || "idle")
    var nextTurn = Number(data.turnCount) || 0

    phase = nextPhase
    wakeEnabled = data.wakeEnabled === true
    wakeGated = data.wakeGated === true
    wakeGateReason = String(data.wakeGateReason || "")
    ttsEnabled = data.ttsEnabled === true
    conversationId = String(data.conversationId || "")
    prompt = String(data.prompt || "")
    statusLine = String(data.statusLine || "")
    reply = String(data.reply || "")
    error = String(data.error || "")
    startedAt = Number(data.startedAt) || 0
    updatedAt = Number(data.updatedAt) || 0
    level = Number(data.level) || 0
    turnCount = nextTurn
    wakeReady = data.wakeReady === true
    ttsReady = data.ttsReady === true

    if (!known) {
      known = true
      return
    }
    if (nextPhase === "error" && prevPhase !== "error" && error !== "" && island && island.hud) {
      island.hud.show({ layout: "toast", title: "Jarvis", body: error, icon: "\u{f015a}", tone: "urgent", duration: 4000 })
    }
    if ((nextPhase === "reply" || nextPhase === "speaking") && (prevPhase === "thinking" || nextTurn > prevTurn) && reply !== "") {
      replyArrived()
    }
  }

  FileView {
    id: stateFile
    path: jarvis.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: jarvis.applyState(text())
  }

  // Fallback poll only while busy in case atomic rename outpaces inotify.
  Timer {
    interval: 150
    repeat: true
    running: jarvis.busy
    onTriggered: {
      jarvis.now = Date.now()
      stateFile.reload()
    }
  }
}
