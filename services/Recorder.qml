import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording with gpu-screen-recorder, which Omarchy's capture uses.
// The process is looked for every two seconds; its age gives the elapsed
// time, which then ticks locally in between.
Item {
  id: recorder

  property var island: null

  // A demo can force it: undefined follows the real recorder.
  property var stand: undefined

  property bool running: false
  property int elapsed: 0

  readonly property bool live: island.settings.showRecording && (stand !== undefined ? stand === true : running)

  Process {
    id: probe
    command: ["sh", "-c", "p=$(pgrep -of '^gpu-screen-recorder') && ps -o etimes= -p \"$p\""]
    stdout: StdioCollector {
      onStreamFinished: {
        if (recorder.stand !== undefined) return
        var seconds = parseInt(String(text || "").trim(), 10)
        recorder.running = !isNaN(seconds)
        if (!isNaN(seconds)) recorder.elapsed = seconds
      }
    }
  }

  function recheck() { if (!probe.running) probe.running = true }

  Timer {
    interval: 2000
    repeat: true
    triggeredOnStart: true
    running: recorder.island.settings.showRecording
    onTriggered: recorder.recheck()
  }

  Timer {
    interval: 1000
    repeat: true
    running: recorder.live
    onTriggered: recorder.elapsed++
  }

  // The same command the bar's recording indicator runs.
  function stop() {
    island.stage.collapse()
    if (stand !== undefined) {
      stand = false
      return
    }
    Quickshell.execDetached(["omarchy-capture-screenrecording", "--stop-recording"])
    recheckSoon.restart()
  }

  Timer { id: recheckSoon; interval: 900; onTriggered: recorder.recheck() }
}
