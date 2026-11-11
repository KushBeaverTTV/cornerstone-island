import QtQuick
import Quickshell.Services.UPower
import "../lib/Glyphs.js" as Glyphs
import "../lib/Format.js" as Format

// The battery, on machines that have one: a HUD when the charger goes in,
// and a warning when the charge drops past 20 % and again past 10 %.
Item {
  id: power

  property var island: null

  readonly property var device: UPower.displayDevice
  readonly property bool present: !!(device && device.isPresent)
  readonly property real level: present ? Format.clamp01(device.percentage) : 0
  readonly property bool charging: present && device.state !== UPowerDeviceState.Discharging
    && device.state !== UPowerDeviceState.Empty && device.state !== UPowerDeviceState.Unknown
  readonly property bool low: present && !charging && level <= 0.2

  onChargingChanged: {
    if (!island.ready || !island.settings.showCharging || !charging) return
    island.lipSweep()
    island.hud.show({ key: "power", layout: "label", label: "Charging", icon: Glyphs.battery(level, true),
                      valueText: Format.percent(level), tone: "green", duration: 2600 })
  }

  property real lastLevel: -1
  onLevelChanged: {
    var before = lastLevel
    lastLevel = level
    if (before < 0 || !island.ready || !island.settings.showCharging || charging) return
    var crossed = [0.2, 0.1].some(function(mark) { return before > mark && level <= mark })
    if (crossed)
      island.hud.show({ key: "power", layout: "label", label: "Low Battery", icon: Glyphs.battery(level, false),
                        valueText: Format.percent(level), tone: "urgent", duration: 3500 })
  }
}
