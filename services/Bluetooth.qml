import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../lib/Glyphs.js" as Glyphs

// Bluetooth devices coming and going: headphones, speakers, keyboards,
// mice, controllers, phones. When `cornerstone.phones` is loaded, headsets
// get rich per-earbud + case battery and ANC mode popups in the island.
Item {
  id: bluetooth

  property var island: null
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var phonesService: island && island.shell && typeof island.shell.serviceFor === "function"
    ? island.shell.serviceFor("cornerstone.phones") : null
  readonly property var headsets: phonesService && Array.isArray(phonesService.followed) ? phonesService.followed : []

  // Devices already connected when the shell starts are not news.
  property bool listening: false
  Timer { interval: 4000; running: true; onTriggered: bluetooth.listening = true }

  function nameOf(device) {
    return String(device.name || device.deviceName || "Bluetooth device").slice(0, 60)
  }

  function batteryOf(device) {
    if (!device.batteryAvailable) return -1
    var b = Number(device.battery)
    return isFinite(b) ? (b > 1 ? b / 100 : b) : -1
  }

  function headsetFor(device) {
    if (!device || !headsets.length) return null
    var addr = String(device.address || "").toUpperCase()
    for (var i = 0; i < headsets.length; i++) {
      var h = headsets[i]
      if (h && String(h.address || "").toUpperCase() === addr) return h
    }
    return null
  }

  function batteryTextFor(device) {
    var h = headsetFor(device)
    if (h) {
      if (h.perBud) {
        var parts = []
        if (h.leftLevel >= 0) parts.push("L " + h.leftLevel + "%")
        if (h.rightLevel >= 0) parts.push("R " + h.rightLevel + "%")
        if (h.caseLevel >= 0 && !h.caseStale) parts.push("C " + h.caseLevel + "%")
        if (parts.length > 0) return parts.join(" · ")
      }
      if (h.level >= 0) return h.level + "%"
    }
    var b = batteryOf(device)
    return b >= 0 ? Math.round(b * 100) + "%" : "Connected"
  }

  function levelRatioFor(device) {
    var h = headsetFor(device)
    if (h && h.level >= 0) return h.level / 100
    return batteryOf(device)
  }

  function modeLabel(mode) {
    var m = String(mode || "").toLowerCase()
    if (m === "anc") return "ANC"
    if (m === "ambient" || m === "transparency") return "Ambient"
    if (m === "off" || m === "normal") return "Off"
    return m ? m.charAt(0).toUpperCase() + m.slice(1) : ""
  }

  // Battery often arrives a moment after the connection, so a connect waits
  // briefly for it (longer when Fast Pair / headset bridge may populate).
  property var arriving: null

  function changed(device) {
    if (!listening || !island.settings.showBluetooth) return
    if (device.connected) {
      arriving = device
      batteryWait.restart()
      return
    }
    island.hud.show({ key: "device", layout: "label", label: nameOf(device), icon: Glyphs.BLUETOOTH_OFF,
                      valueText: "Disconnected", tone: "dim", duration: 2200 })
  }

  Timer {
    id: batteryWait
    interval: 1400
    onTriggered: {
      var device = bluetooth.arriving
      bluetooth.arriving = null
      if (!device || !device.connected) return
      var ratio = bluetooth.levelRatioFor(device)
      bluetooth.island.hud.show({
        key: "device", layout: "label", label: bluetooth.nameOf(device), icon: Glyphs.device(device.icon),
        valueText: bluetooth.batteryTextFor(device),
        tone: ratio >= 0 && ratio <= 0.2 ? "urgent" : "green", duration: 3200
      })
    }
  }

  Instantiator {
    model: bluetooth.devices
    delegate: Connections {
      required property var modelData
      target: modelData
      function onConnectedChanged() { bluetooth.changed(modelData) }
    }
  }

  // Show a subtle island HUD when a headset's ANC / Ambient mode changes.
  Instantiator {
    model: bluetooth.headsets
    delegate: Connections {
      required property var modelData
      target: modelData
      property string lastMode: ""
      function onModeChanged() {
        var next = String(modelData.mode || "")
        if (!bluetooth.listening || !bluetooth.island.settings.showBluetooth || !modelData.connected || !modelData.live) {
          lastMode = next
          return
        }
        if (lastMode !== "" && next !== "" && next !== lastMode) {
          bluetooth.island.hud.show({
            key: "device", layout: "label",
            label: String(modelData.name || "Headphones").slice(0, 60),
            icon: Glyphs.HEADPHONES,
            valueText: bluetooth.modeLabel(next),
            tone: next === "anc" ? "accent" : "fg",
            duration: 2200
          })
        }
        lastMode = next
      }
    }
  }
}
