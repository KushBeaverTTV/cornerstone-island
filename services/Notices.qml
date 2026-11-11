import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../lib/Notices.js" as Notices

// The island's notification service.
//
// Only one program can own org.freedesktop.Notifications, so this serves
// only while Omarchy's own omarchy.notifications is disabled (see
// core/Integration.qml). It answers on the same `notifications` IPC target,
// so Omarchy's keybindings and scripts (dismiss, invoke, history, silence)
// keep working, and it shares Omarchy's do-not-disturb file.
//
// A notification's life, iOS style:
//   banner  it drops out of the island for a few seconds;
//   inbox   if nobody clicked or closed it, it waits there (a bell with a
//           count) until opened or cleared;
//   gone    a click jumps to the app, the × clears it.
Item {
  id: notices

  property var island: null
  // Held off until Omarchy's service has let go of the bus name.
  property bool serving: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/omarchy/dynamic-island"
  readonly property int inboxLimit: 50

  // Newest first. Each entry is a plain record (lib/Notices.js) plus `live`,
  // the sender's Notification while it still holds it (for actions and
  // updates), and `demo` for pretend ones, which are never saved.
  property var banners: []
  property var inbox: []
  readonly property var current: banners.length > 0 ? banners[0] : null
  readonly property int waiting: Math.max(0, banners.length - 1)
  property bool silenced: false
  property int lastKey: 0
  property bool closing: false

  // A banner still on screen when the shell stops (a restart, a reload)
  // would otherwise be lost: it goes into the saved inbox first.
  Component.onDestruction: {
    if (restored) {
      var keep = banners.filter(function(e) { return !e.demo && !Notices.isFeedback(e.app) })
      if (keep.length > 0) {
        var rows = keep.concat(inbox).filter(function(e) { return !e.demo })
          .sort(function(a, b) { return b.time - a.time }).slice(0, inboxLimit).map(Notices.persistable)
        inboxFile.setText(JSON.stringify(rows) + "\n")
      }
    }
    closing = true
  }

  // ------------------------------------------------------------ the server
  LazyLoader {
    active: notices.serving

    NotificationServer {
      keepOnReload: false
      imageSupported: true
      actionsSupported: true
      bodyMarkupSupported: true
      bodyHyperlinksSupported: false
      persistenceSupported: true
      onNotification: function(notification) { notices.receive(notification) }
    }
  }

  function nextKey() { return ++lastKey }

  function receive(n) {
    n.tracked = true
    var actions = []
    try {
      for (var i = 0; i < n.actions.length; i++) {
        var a = n.actions[i]
        if (a && a.identifier !== "default" && a.text) actions.push({ id: String(a.identifier), text: String(a.text).slice(0, 40) })
      }
    } catch (e) {}
    var entry = Notices.record({
      app: n.appName, appIcon: n.appIcon, desktopEntry: n.desktopEntry,
      summary: n.summary, body: n.body, image: n.image,
      // Omarchy's own toasts: a Nerd Font glyph for the icon and a command
      // to run on click (omarchy-notification-send --glyph / --exec).
      glyph: Notices.hint(n.hints, "omarchy-glyph"),
      execArgv: Notices.hint(n.hints, "omarchy-exec-argv"),
      critical: n.urgency === NotificationUrgency.Critical,
      low: n.urgency === NotificationUrgency.Low,
      timeout: n.expireTimeout,
      actions: actions
    }, nextKey(), Date.now())
    entry.live = n

    // Withdrawn by its sender (read elsewhere, app closed it): gone
    // everywhere, without echoing a close back. Objects torn down with the
    // shell also report `closed`, and those must stay in the saved inbox.
    n.closed.connect(function(reason) {
      if (!notices.closing && reason === NotificationCloseReason.CloseRequested) notices.take(entry.key, "")
    })

    // An update (replaces_id) arrives as the same object: it replaces the
    // earlier one rather than stacking on it.
    banners = banners.filter(function(e) { return e.live !== n })
    if (inbox.some(function(e) { return e.live === n })) setInbox(inbox.filter(function(e) { return e.live !== n }))

    if (silenced && !Notices.breaksSilence(entry)) {
      // Silenced: no banner, straight to the inbox so nothing is missed.
      if (Notices.isFeedback(entry.app)) n.tracked = false
      else file(entry)
      return
    }
    banners = [entry].concat(banners)
  }

  // A pretend notification for demos, with no sender behind it.
  function pretend(fields) {
    var entry = Notices.record(fields, nextKey(), Date.now())
    entry.live = null
    entry.demo = true
    banners = [entry].concat(banners)
    return entry.key
  }

  function find(key) {
    var all = banners.concat(inbox)
    for (var i = 0; i < all.length; i++) if (all[i].key === key) return all[i]
    return null
  }

  function setInbox(list) {
    inbox = list
    save()
  }

  // Take an entry out of the banners and the inbox. `tell` is how the
  // sender hears of it: "dismiss" (the user cleared it), "expire", or ""
  // (say nothing).
  function take(key, tell) {
    var entry = find(key)
    if (!entry) return null
    banners = banners.filter(function(e) { return e.key !== key })
    if (inbox.some(function(e) { return e.key === key })) setInbox(inbox.filter(function(e) { return e.key !== key }))
    var live = entry.live
    entry.live = null
    if (live && tell) {
      try { if (tell === "dismiss") live.dismiss(); else live.expire() } catch (e) {}
    }
    return entry
  }

  // Into the inbox, newest arrival first however long each banner stayed.
  function file(entry) {
    var rest = inbox.filter(function(e) { return e.key !== entry.key })
    setInbox([entry].concat(rest).sort(function(a, b) { return b.time - a.time }).slice(0, inboxLimit))
  }

  // A banner's time ran out without a click: to the inbox, unless it was
  // only feedback (Omarchy's "Theme changed" and friends).
  function retire(key) {
    var entry = find(key)
    if (!entry) return
    if (Notices.isFeedback(entry.app)) {
      take(key, "expire")
      return
    }
    banners = banners.filter(function(e) { return e.key !== key })
    file(entry)
  }

  // A click: the sender's own handling (its default action, or Omarchy's
  // exec command), then its window comes forward, so a click always lands
  // in the app the notification came from.
  function open(key) {
    var entry = find(key)
    if (!entry) return
    var argv = Notices.execArgv(entry.execArgv)
    if (argv) {
      Quickshell.execDetached(["bash", "-lc", 'exec "$@"', "bash"].concat(argv))
    } else {
      invokeLive(entry, "default")
      focusApp(entry)
    }
    take(key, "dismiss")
  }

  function invokeLive(entry, id) {
    try {
      var list = entry.live ? entry.live.actions : []
      for (var i = 0; i < list.length; i++)
        if (list[i] && list[i].identifier === id) { list[i].invoke(); return true }
    } catch (e) {}
    return false
  }

  // Omarchy's helper finds a window by class: try the sender's desktop entry
  // (usually the class), then its app name.
  function focusApp(entry) {
    var app = Notices.isFeedback(entry.app) ? "" : entry.app
    if (!app && !entry.desktopEntry) return
    Quickshell.execDetached(["sh", "-c",
      'f="$OMARCHY_PATH/bin/omarchy-hyprland-focus-app"; { [ -n "$1" ] && "$f" "$1"; } || { [ -n "$2" ] && "$f" "$2"; }',
      "sh", entry.desktopEntry, app])
  }

  function act(key, actionId) {
    var entry = find(key)
    if (!entry) return
    invokeLive(entry, actionId)
    take(key, "dismiss")
  }

  function dismiss(key) { take(key, "dismiss") }

  function clearAll() {
    banners.concat(inbox).map(function(e) { return e.key }).forEach(function(key) { take(key, "dismiss") })
  }

  // Pretend ones go when a demo ends.
  function clearDemos() {
    banners.concat(inbox).filter(function(e) { return e.demo }).forEach(function(e) { take(e.key, "") })
  }

  // The newest one on screen, else the newest waiting (for keybindings).
  function newestKey() {
    if (current) return current.key
    return inbox.length > 0 ? inbox[0].key : -1
  }

  // The banner's time, paused while the pointer is on the island.
  Timer {
    id: bannerTimer
    interval: Math.max(1000, Notices.bannerMs(notices.current))
    running: notices.current !== null && Notices.bannerMs(notices.current) > 0
      && !(notices.island && notices.island.stage.hovered)
    onTriggered: if (notices.current) notices.retire(notices.current.key)
  }

  onCurrentChanged: if (bannerTimer.running) bannerTimer.restart()

  // A notification's icon as an image address that will really load, or ""
  // for the glyph. Quickshell hands an app icon over as image://icon/<name>
  // even when the theme has no such icon (which draws a magenta
  // checkerboard), so theme names are checked first.
  function themed(name) {
    var n = String(name || "")
    if (n === "") return ""
    if (n.charAt(0) === "/") return "file://" + n
    return Quickshell.iconPath(n, true) || ""
  }

  function iconFor(entry) {
    if (!entry || entry.glyph) return ""
    var image = String(entry.image || "")
    if (image !== "") {
      if (image.charAt(0) === "/") return "file://" + image
      if (image.indexOf("image://icon/") === 0) return themed(image.slice(13))
      return image
    }
    var icon = String(entry.appIcon || "")
    if (icon.indexOf("image://icon/") === 0) icon = icon.slice(13)
    else if (icon.indexOf("://") !== -1) return icon
    var found = themed(icon)
    if (found) return found
    var desktop = entry.desktopEntry ? DesktopEntries.byId(entry.desktopEntry) : null
    if (!desktop && entry.app) desktop = DesktopEntries.heuristicLookup(entry.app)
    return desktop && desktop.icon ? themed(desktop.icon) : ""
  }

  // ------------------------------------------------------------ inbox file
  // Records only: after a restart the senders are gone, so restored rows
  // open by focusing their app.
  property bool restored: false

  function save() {
    if (closing || !restored) return
    var rows = inbox.filter(function(e) { return !e.demo }).map(Notices.persistable)
    inboxFile.setText(JSON.stringify(rows) + "\n")
  }

  function restore(text) {
    var rows
    try { rows = JSON.parse(text || "[]") } catch (e) { rows = [] }
    if (!Array.isArray(rows)) rows = []
    var back = rows.slice(0, inboxLimit).map(function(r) {
      var entry = Notices.record(r, notices.nextKey(), Date.now())
      entry.live = null
      return entry
    })
    restored = true
    inbox = back.concat(inbox)
  }

  Process {
    running: true
    command: ["mkdir", "-p", notices.stateDir]
    onExited: inboxFile.reload()
  }

  FileView {
    id: inboxFile
    path: notices.stateDir + "/inbox.json"
    printErrors: false
    atomicWrites: true
    onLoaded: if (!notices.restored) notices.restore(text())
    // No inbox yet: nothing to restore.
    onLoadFailed: notices.restored = true
  }

  // ------------------------------------------------------------- silencing
  function setSilenced(value) {
    silenced = !!value
    silenceFile.setText(JSON.stringify({ version: 3, dnd: silenced }, null, 2) + "\n")
    island.hud.show({ key: "dnd", layout: "label", label: silenced ? "Silenced" : "Notifications On",
                      icon: silenced ? "\u{f009b}" : "\u{f009a}", valueText: "", tone: silenced ? "orange" : "fg",
                      duration: 1800 })
  }

  FileView {
    id: silenceFile
    path: notices.home + "/.local/state/omarchy/notifications.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try { notices.silenced = JSON.parse(text() || "{}").dnd === true } catch (e) {}
    }
  }

  // ------------------------------------------------------------------ IPC
  // Omarchy's own target and methods, so SUPER+, and friends,
  // omarchy-toggle-notification-silencing and omarchy-notification-* work.
  IpcHandler {
    target: "notifications"
    enabled: notices.serving

    function dndState(): string { return notices.silenced ? "on" : "off" }
    function toggleDnd(): string { notices.setSilenced(!notices.silenced); return dndState() }
    function setDnd(value: string): string {
      notices.setSilenced(["true", "1", "on", "yes"].indexOf(String(value || "").toLowerCase()) !== -1)
      return dndState()
    }
    function isDnd(): string { return dndState() }
    // Omarchy's "notification history" keybinding opens the inbox.
    function showHistory(): string {
      notices.island.stage.openInbox()
      return notices.inbox.length > 0 ? "ok" : "none"
    }
    function clear(): string { notices.clearAll(); return "ok" }
    function dismissAll(): string { notices.clearAll(); return "ok" }
    function dismissOne(): string {
      var key = notices.newestKey()
      if (key < 0) return "none"
      notices.dismiss(key)
      return "ok"
    }
    function invokeLast(): string {
      var key = notices.newestKey()
      if (key < 0) return "none"
      notices.open(key)
      return "ok"
    }
    function dismiss(summary: string): string {
      var needle = String(summary || "")
      if (needle === "") return "none"
      var keys = notices.banners.concat(notices.inbox)
        .filter(function(e) { return e.summary.indexOf(needle) !== -1 })
        .map(function(e) { return e.key })
      keys.forEach(notices.dismiss)
      return keys.length > 0 ? "ok" : "none"
    }
    function ping(): string { return "ok" }
  }
}
