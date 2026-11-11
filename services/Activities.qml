import QtQuick

// Live activities pushed by scripts: a build, a download, a backup, an
// agent at work. Anything can start, update and end one over IPC:
//
//   omarchy-shell dynamic-island activity build '{"title":"Building","progress":0.4}'
//   omarchy-shell dynamic-island endActivity build "Done"
//
// Payload fields, all optional: title, subtitle, icon (a Nerd Font glyph),
// progress (0..1; leave it out for none), value (short text such as
// "3/10"), color (accent, green, orange, red, or #hex), ttl (seconds until
// it ends by itself). An update only changes the fields it carries. The
// most recently updated activity is the one shown.
Item {
  id: activities

  property var island: null
  property var byId: ({})

  readonly property var all: Object.keys(byId).map(function(id) { return byId[id] })
  readonly property var current: all.reduce(function(best, a) { return !best || a.updated > best.updated ? a : best }, null)

  function text(value, fallback, max) {
    return value === undefined || value === null ? fallback : String(value).slice(0, max)
  }

  function upsert(id, payload) {
    var key = String(id || "").trim().slice(0, 64)
    if (key === "") return "missing id"
    var p = payload && typeof payload === "object" ? payload : {}
    var was = byId[key] || {}
    var progress = p.progress === undefined ? was.progress : Number(p.progress)
    var ttl = Number(p.ttl)
    var next = Object.assign({}, byId)
    next[key] = {
      id: key,
      title: text(p.title, was.title || key, 120),
      subtitle: text(p.subtitle, was.subtitle || "", 200),
      icon: text(p.icon, was.icon || "\u{f012c}", 8),
      progress: progress === undefined || progress === null || !isFinite(progress) || progress < 0 ? -1 : Math.min(1, progress),
      value: text(p.value, was.value || "", 24),
      color: text(p.color, was.color || "", 24),
      expires: p.ttl !== undefined && ttl > 0 ? Date.now() + ttl * 1000 : (was.expires || 0),
      updated: Date.now()
    }
    byId = next
    return "ok"
  }

  // End one; a message shows as a toast in the activity's colour.
  function end(id, message) {
    var key = String(id || "")
    var ended = byId[key]
    if (!ended) return "none"
    var next = Object.assign({}, byId)
    delete next[key]
    byId = next
    if (message)
      island.hud.show({ layout: "toast", title: ended.title, body: String(message).slice(0, 200), icon: ended.icon,
                        tone: ended.color || "green", duration: 4000 })
    return "ok"
  }

  // A crashed script must not leave its activity up forever: ttl runs out.
  Timer {
    interval: 5000
    repeat: true
    running: activities.all.length > 0
    onTriggered: {
      var now = Date.now()
      activities.all.filter(function(a) { return a.expires > 0 && a.expires <= now })
        .forEach(function(a) { activities.end(a.id, "") })
    }
  }
}
