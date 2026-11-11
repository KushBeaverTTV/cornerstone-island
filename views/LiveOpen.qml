import QtQuick
import "../ui"

// A script's live activity, opened. The ✕ ends it.
ActivityCard {
  id: view

  property var island: null
  readonly property var item: island.activities.current
  look: island.look
  glyph: item ? item.icon : ""
  tone: look.tone(item ? item.color : "")
  progress: item ? item.progress : -1
  title: item ? item.title : ""
  detail: item ? item.subtitle : ""
  value: !item ? "" : (item.value !== "" ? item.value : (item.progress >= 0 ? Math.round(item.progress * 100) + "%" : ""))

  onClose: {
    if (item) island.activities.end(item.id, "")
    island.stage.done()
  }
}
