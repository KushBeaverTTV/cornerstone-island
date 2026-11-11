import QtQuick
import Quickshell
import "../lib/Config.js" as Config
import "../lib/Scripts.js" as Scripts

// How the island fits into Omarchy.
//
// Takeovers: the island replaces Omarchy's notification service and its
// on-screen display (the volume, brightness, microphone, keyboard light,
// power and download popups). Only one program can do each job, so the
// island disables the Omarchy plugin, leaving a marker file in
// ~/.local/state/omarchy/dynamic-island so it knows it was the one, and
// starts serving once that plugin has let go. "notifications": false or
// "osd": false gives a job back; so does removing the island.
//
// Keybinding: the "keybind" setting (SUPER + ALT + I) toggles reserveSpace.
// It lives in a marked block in ~/.config/hypr/bindings.lua: a key that
// something else uses is left alone, "keybind": false drops the block, and
// removing the island removes it.
Item {
  id: integration

  property var island: null
  readonly property var settings: island.settings
  // Copied, so it is still at hand while the island is being torn down.
  readonly property string pluginId: island.pluginId

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island"
  readonly property string bindingsPath: Quickshell.env("HOME") + "/.config/hypr/bindings.lua"

  readonly property bool omarchyNotificationsOff: settings.disabledPlugins.indexOf("omarchy.notifications") !== -1
  readonly property bool omarchyOsdOff: settings.disabledPlugins.indexOf("omarchy.osd") !== -1

  // Whether the island does the job now. Set a moment after Omarchy's plugin
  // is off, so it has let go of the bus name first.
  property bool servingNotifications: false
  property bool servingOsd: false

  // What has been asked of Omarchy this session, so a request is sent once.
  property var asked: ({})

  function sync() {
    if (!settings.loaded) return
    request("notifications", settings.wantsNotifications, omarchyNotificationsOff)
    request("osd", settings.wantsOsd, omarchyOsdOff)
    if (!(settings.wantsNotifications && omarchyNotificationsOff)) servingNotifications = false
    if (!(settings.wantsOsd && omarchyOsdOff)) servingOsd = false
    settle.restart()
  }

  function request(name, wanted, omarchyOff) {
    if (wanted === omarchyOff || asked[name]) return
    asked[name] = true
    Quickshell.execDetached(wanted ? Scripts.takeOver(stateDir, name) : Scripts.giveBack(stateDir, name))
  }

  Timer {
    id: settle
    interval: 1500
    onTriggered: {
      integration.servingNotifications = integration.settings.wantsNotifications && integration.omarchyNotificationsOff
      integration.servingOsd = integration.settings.wantsOsd && integration.omarchyOsdOff
    }
  }

  function syncKeybind() {
    if (!settings.loaded) return
    var parsed = Config.parseKeybind(settings.keybind)
    Quickshell.execDetached(parsed
      ? Scripts.writeKeybind(bindingsPath, pluginId, settings.keybind, parsed)
      : Scripts.removeKeybind(bindingsPath, pluginId))
  }

  Connections {
    target: integration.settings
    function onLoadedChanged() { integration.sync(); integration.syncKeybind() }
    function onWantsNotificationsChanged() { integration.sync() }
    function onWantsOsdChanged() { integration.sync() }
    function onKeybindChanged() { integration.syncKeybind() }
  }
  onOmarchyNotificationsOffChanged: sync()
  onOmarchyOsdOffChanged: sync()
  Component.onCompleted: { sync(); syncKeybind() }

  // Everything goes back if the island has really been removed; see
  // Scripts.handBackIfRemoved for why this waits and what it checks.
  Component.onDestruction: Quickshell.execDetached(Scripts.handBackIfRemoved(pluginId, stateDir, bindingsPath))
}
