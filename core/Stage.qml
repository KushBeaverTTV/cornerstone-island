import QtQuick
import "../lib/Layout.js" as Layout

// Decides what the island is showing and how big it is, from what is live,
// what just happened (HUDs, banners) and what the user did (opened it,
// hovered it, picked a panel). Everything here is derived or a small piece
// of user state; the live data itself lives in the services.
Item {
  id: stage

  property var island: null
  readonly property var settings: island.settings
  readonly property var look: island.look

  // ---- user state
  property bool open: false
  // An opened island can show one of these panels instead of an activity.
  property string panel: ""            // "", "inbox", "outputs", "calendar"
  // Which activity an opened island is about (the bubble's, when the
  // bubble was what got clicked).
  property string about: ""
  // The calendar's "add a link" field. Kept here, not in the view, because
  // the window takes the keyboard only while it is up.
  property bool calendarAdding: false
  property bool hovered: false
  // True while the user is actively dragging a slider inside the island, so
  // drifting slightly outside the pill mid-drag does not collapse it.
  property bool interacting: false

  readonly property bool typing: calendarAdding && view === "calendar-expanded"

  // ---- what is live, by rank
  readonly property var live: Layout.rankLive({
    recording: island.recorder.live,
    dictation: island.dictation.live,
    timer: island.clocks.timerActive,
    activity: island.activities.current !== null,
    media: island.media.live,
    stopwatch: island.clocks.stopwatchActive,
    calendar: settings.showCalendar && island.calendar.soon,
    mic: island.privacy.live,
    inbox: settings.showInbox && island.notices.inbox.length > 0
  })
  readonly property string primary: live.length > 0 ? live[0] : ""
  readonly property string secondary: live.length > 1 ? live[1] : ""

  readonly property var banner: island.notices.current

  readonly property string view: Layout.chooseView({
    open: open,
    panel: panel,
    focus: about,
    live: live,
    hasMedia: island.media.present,
    hud: island.hud.current,
    banner: banner !== null,
    bannerActions: banner !== null && banner.actions.length > 0,
    idleHidden: settings.idleHidden,
    hovered: hovered
  })

  readonly property bool resting: view === "idle" || view === "idle-hover"
  readonly property bool showBubble: secondary !== "" && !open && island.hud.current === null

  // ---- size
  readonly property var counts: ({ inbox: island.notices.inbox.length, outputs: island.sound.outputs.length })

  function shapeOf(name) {
    return Layout.shape(name, counts, settings.cutout)
  }

  // The resting pill fits what the glance is showing, so it breathes a
  // little as the glances change.
  TextMetrics {
    id: glanceText
    font.family: stage.look.mono
    font.pixelSize: stage.look.f(12)
    font.bold: true
    text: island.glance.current ? island.glance.current.text : ""
  }

  readonly property var target: {
    var base = shapeOf(view)
    if (!resting || (settings.idleFace !== "ticker" && settings.idleFace !== "clock")) return base
    var needed = Math.ceil(glanceText.advanceWidth / look.unit) + 44 + (view === "idle-hover" ? 12 : 0)
    return { w: Math.min(260, Math.max(base.w, needed)), h: base.h, r: base.r }
  }

  // ---- actions
  function expand(autoCloseMs) {
    island.hud.clear()
    open = true
    // Opened without the pointer on it (IPC, keybind): it closes by itself.
    if (!hovered) {
      leaveTimer.interval = autoCloseMs || 6000
      leaveTimer.restart()
    }
  }

  function collapse() {
    open = false
    panel = ""
    about = ""
    calendarAdding = false
    leaveTimer.stop()
  }

  function toggle() {
    if (open) collapse()
    else expand()
  }

  function openPanel(name, autoCloseMs) {
    panel = name
    expand(autoCloseMs)
  }

  // The list of waiting notifications (bell click, or Omarchy's
  // notification-history keybind).
  function openInbox() { openPanel("inbox", 8000) }

  function openCalendar() {
    // No calendars yet: open straight into the field for adding one.
    calendarAdding = island.calendar.sources.length === 0
    openPanel("calendar", 10000)
  }

  function openOutputs() { openPanel("outputs") }
  function closeOutputs() { if (panel === "outputs") panel = "" }

  // A view's own action finished with the island (a button that did its
  // job): close it.
  function done() { collapse() }

  function clicked(button) {
    if (button === Qt.MiddleButton) {
      island.media.toggle()
      return
    }
    // The bell owns the pill when nothing else is live: it opens the inbox.
    if (!open && primary === "inbox") {
      openInbox()
      return
    }
    toggle()
  }

  function bubbleClicked() {
    if (secondary === "inbox") {
      openInbox()
      return
    }
    about = secondary
    expand()
  }

  // Leaving an opened island closes it, the way a notch shelf does, unless
  // the calendar field has the keyboard or a slider is being dragged.
  Timer {
    id: leaveTimer
    interval: 500
    onTriggered: if (!stage.hovered && !stage.typing && !stage.interacting) stage.collapse()
  }

  onInteractingChanged: {
    if (interacting) {
      leaveTimer.stop()
    } else if (open && !hovered && !typing) {
      leaveTimer.interval = 500
      leaveTimer.restart()
    }
  }

  Timer {
    id: hoverOpenTimer
    interval: 380
    onTriggered: if (stage.hovered && !stage.open) stage.expand()
  }

  onHoveredChanged: {
    if (hovered) {
      leaveTimer.stop()
      if (settings.expandOnHover) hoverOpenTimer.restart()
      return
    }
    hoverOpenTimer.stop()
    if (open) {
      leaveTimer.interval = 500
      leaveTimer.restart()
    }
  }

  // An inbox emptied from inside closes with its last row.
  Connections {
    target: island.notices
    function onInboxChanged() {
      if (stage.open && stage.panel === "inbox" && island.notices.inbox.length === 0) stage.collapse()
    }
  }
}
