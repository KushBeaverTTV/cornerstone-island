import QtQuick
import Quickshell.Services.Pipewire
import "../lib/Glyphs.js" as Glyphs

// The default output: its volume HUD, scrolling on the island to change
// it, and the "Play on" list of every output to move sound to.
Item {
  id: sound

  property var island: null

  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: sound.sink ? [sound.sink] : [] }

  readonly property bool ready: !!sink && !!sink.audio
  readonly property real volume: ready ? sink.audio.volume : 0
  readonly property bool muted: ready ? sink.audio.muted : false

  onVolumeChanged: announce()
  onMutedChanged: announce()

  function announce() {
    if (!island.ready || !island.settings.showVolume || !ready) return
    island.hud.show({
      key: "volume",
      layout: "progress",
      icon: Glyphs.volume(volume, muted),
      value: muted ? 0 : volume,
      valueText: muted ? "Mute" : Math.round(volume * 100) + "%",
      dim: muted,
      duration: 1500
    })
  }

  // One wheel notch is 5 %; scrolling up also unmutes.
  function nudge(wheelDelta) {
    if (!ready || wheelDelta === 0) return
    sink.audio.muted = false
    sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (wheelDelta > 0 ? 0.05 : -0.05)))
  }

  // ---- outputs
  readonly property var outputs: (Pipewire.nodes ? Pipewire.nodes.values : [])
    .filter(function(n) { return n && n.isSink && !n.isStream && n.audio })

  function nameOf(node) {
    return String(node && (node.description || node.nickname || node.name) || "")
  }

  // Outputs of one card share a long prefix ("Navi 31 HDMI/DP Audio ...");
  // the words every output of the same card starts with are dropped, so
  // what is left tells them apart. Other cards (a headset) do not count.
  function label(node) {
    var name = nameOf(node)
    var words = name.split(" ")
    var siblings = outputs.map(nameOf).filter(function(n) { return n.split(" ")[0] === words[0] })
    if (siblings.length < 2) return name
    var shared = 0
    while (shared < words.length - 1 && siblings.every(function(n) {
      var w = n.split(" ")
      return w.length > shared + 1 && w[shared] === words[shared]
    })) shared++
    return words.slice(shared).join(" ") || name
  }

  function glyph(node) { return Glyphs.output(node) }

  function isCurrent(node) { return !!sink && !!node && sink.id === node.id }

  function choose(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    island.stage.closeOutputs()
    island.hud.show({ key: "output", layout: "label", label: label(node), icon: glyph(node),
                      valueText: "Playing on", tone: "accent", duration: 1800 })
  }
}
