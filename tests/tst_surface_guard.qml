import QtQuick
import QtTest
import "../chrome"

TestCase {
  name: "SurfaceGuard"

  QtObject { id: screenA; property int x: 0; property int y: 0 }
  QtObject { id: screenB; property int x: 0; property int y: 0 }
  QtObject { id: window; signal closed() }

  SurfaceGuard {
    id: guard
    window: window
    targetScreen: screenA
  }

  function init() {
    guard.targetScreen = screenA
    tryCompare(guard, "ready", true)
  }

  function test_monitor_unplugged_and_back() {
    guard.targetScreen = null
    compare(guard.ready, false)
    wait(250)
    compare(guard.ready, false)
    guard.targetScreen = screenA
    compare(guard.ready, false)
    tryCompare(guard, "ready", true)
  }

  function test_compositor_closes_surface() {
    window.closed()
    tryCompare(guard, "ready", false)
    tryCompare(guard, "ready", true)
  }

  function test_repeated_close_waits_to_settle() {
    window.closed()
    tryCompare(guard, "ready", false)
    wait(100)
    window.closed()
    wait(125)
    compare(guard.ready, false)
    tryCompare(guard, "ready", true)
  }

  function test_other_screen() {
    guard.targetScreen = screenB
    compare(guard.ready, false)
    tryCompare(guard, "ready", true)
  }

  function test_monitor_moves() {
    screenA.x += 100
    compare(guard.ready, false)
    tryCompare(guard, "ready", true)
    screenA.y += 100
    compare(guard.ready, false)
    tryCompare(guard, "ready", true)
  }
}
