import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../lib/Glyphs.js" as Glyphs

// Bluetooth devices coming and going: headphones, speakers, keyboards,
// mice, controllers, phones. A device that reports its battery shows it.
Item {
  id: bluetooth

  property var island: null
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []

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

  // Battery often arrives a moment after the connection, so a connect waits
  // briefly for it.
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
    interval: 1200
    onTriggered: {
      var device = bluetooth.arriving
      bluetooth.arriving = null
      if (!device || !device.connected) return
      var battery = bluetooth.batteryOf(device)
      bluetooth.island.hud.show({
        key: "device", layout: "label", label: bluetooth.nameOf(device), icon: Glyphs.device(device.icon),
        valueText: battery >= 0 ? Math.round(battery * 100) + "%" : "Connected",
        tone: battery >= 0 && battery <= 0.2 ? "urgent" : "green", duration: 3000
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
}
