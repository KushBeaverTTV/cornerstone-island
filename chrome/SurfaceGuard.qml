import QtQuick

// Keeps the island's layer surface on screen through monitor changes.
//
// A compositor can close a layer surface when its output goes away without
// the QML window being destroyed, and Hyprland leaves a mapped surface at
// its old position when its monitor moves in the layout. Rebinding the
// window's screen does not reopen it either. So whenever the screen
// changes, the surface is closed, or the monitor moves, the window is kept
// unmapped (`ready` false) until things have been still for a moment, then
// mapped again. The island's state lives outside the window and survives.
Item {
  id: guard

  required property var window
  required property var targetScreen
  property int settleMs: 200

  property bool holding: false
  readonly property bool ready: targetScreen !== null && !holding

  visible: false

  function hold() {
    holding = true
    settle.restart()
  }

  onTargetScreenChanged: hold()

  Timer {
    id: settle
    interval: guard.settleMs
    onTriggered: guard.holding = false
  }

  Connections {
    target: guard.window
    // Reopening right away would race Quickshell's own close handling.
    function onClosed() { Qt.callLater(guard.hold) }
  }

  Connections {
    target: guard.targetScreen
    function onXChanged() { guard.hold() }
    function onYChanged() { guard.hold() }
  }
}
