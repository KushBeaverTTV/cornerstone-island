import QtQuick

// Short-lived messages over the island: levels (volume, brightness),
// status lines (charging, a device connecting), the now-playing card and
// toasts.
//
// A HUD is { layout: "progress" | "label" | "track" | "toast", key?, duration,
// ...what its view shows }. How they share the island:
//   - one with the same `key` as the one showing replaces it in place, so a
//     held volume key updates a single HUD;
//   - a level never waits: it covers whatever is showing, and a toast or
//     status it covered comes back afterwards for the time it had left;
//   - other messages queue (a few at most) instead of wiping each other out,
//     so "Typed 12 words" is not lost under "Build finished".
Item {
  id: hud

  property var current: null
  property var queue: []
  // A message a level covered, and how long it still had.
  property var covered: null
  property int coveredLeft: 0
  property double shownAt: 0

  readonly property int queueLimit: 3
  readonly property int minimumMs: 600

  function durationOf(spec) {
    return Math.max(minimumMs, Math.min(60000, Number(spec.duration) || 1600))
  }

  function show(spec) {
    if (!spec) return
    var next = spec
    if (current && next.key && next.key === current.key) {
      present(next)
      return
    }
    if (!current || current.layout === "progress") {
      present(next)
      return
    }
    if (next.layout === "progress") {
      var left = durationOf(current) - (Date.now() - shownAt)
      if (left > 400) { covered = current; coveredLeft = left }
      present(next)
      return
    }
    // Queue; a queued message with the same key is brought up to date.
    var rest = queue.filter(function(q) { return !(next.key && q.key === next.key) })
    rest.push(next)
    queue = rest.slice(-queueLimit)
  }

  function present(spec, ms) {
    current = spec
    shownAt = Date.now()
    timer.interval = ms || durationOf(spec)
    timer.restart()
  }

  // Done with the current one: what it covered, else the next in line.
  function advance() {
    if (covered) {
      var back = covered
      covered = null
      present(back, Math.max(1200, coveredLeft))
      return
    }
    if (queue.length > 0) {
      var next = queue[0]
      queue = queue.slice(1)
      present(next)
      return
    }
    current = null
  }

  // Drop one kind (e.g. every OSD level when the OSD is told to close).
  function dismiss(keys) {
    queue = queue.filter(function(q) { return keys.indexOf(q.key) === -1 })
    if (covered && keys.indexOf(covered.key) !== -1) covered = null
    if (current && keys.indexOf(current.key) !== -1) { timer.stop(); advance() }
  }

  function clear() {
    timer.stop()
    current = null
    covered = null
    queue = []
  }

  Timer {
    id: timer
    onTriggered: hud.advance()
  }
}
