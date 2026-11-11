import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

// Something is using the microphone or the camera.
//
// Microphone: any PipeWire capture stream, except level meters and monitor
// taps (not a privacy signal) and Cornerstone's own recorder, which the
// island shows as dictation instead. Camera: any process holding a
// /dev/video* device open.
Item {
  id: privacy

  property var island: null

  // A demo can force either one: undefined follows the real state.
  property var standMic: undefined
  property var standCamera: undefined

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  // Streams that are not a person being listened to.
  readonly property var quietStreams: ["peak", "monitor", "cava"]
  readonly property string dictationRecorder: "cornerstone-dictation"

  function isListening(node) {
    if (!node || !node.isStream || node.isSink !== false) return false
    var name = String(node.name || "").toLowerCase()
    if (name === dictationRecorder) return false
    return !quietStreams.some(function(word) { return name.indexOf(word) !== -1 })
  }

  readonly property bool micInUse: standMic !== undefined ? standMic === true : nodes.some(isListening)
  property bool cameraSeen: false
  readonly property bool cameraInUse: island.settings.showCamera
    && (standCamera !== undefined ? standCamera === true : cameraSeen)

  readonly property bool live: (island.settings.showMic && micInUse) || cameraInUse

  Process {
    id: cameraProbe
    command: ["sh", "-c", "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -print -quit 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: privacy.cameraSeen = String(text || "").trim() !== ""
    }
  }

  function recheck() { if (!cameraProbe.running) cameraProbe.running = true }

  Timer {
    interval: 3000
    repeat: true
    triggeredOnStart: true
    running: privacy.island.settings.showCamera && privacy.standCamera === undefined
    onTriggered: privacy.recheck()
  }
}
