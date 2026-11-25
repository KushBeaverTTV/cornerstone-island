import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Commons
import "../lib/Notices.js" as Notices

// A picture or app icon in a rounded tile: album covers, posters, notification
// images and app icons. Accepts either a single `source` or an ordered
// `sources` fallback list; when one address fails to load it advances to the
// next, falling back to a tinted glyph only when every candidate fails.
//
// Photos/covers crop cleanly into the rounded tile with no halo; full-colour
// app icons fit whole without cropping or a mismatched backdrop; monochrome
// freedesktop `-symbolic` icons are tinted to stay visible on dark surfaces.
Item {
  id: cover

  property var look: null
  property string source: ""
  property var sources: []
  property color tint: look ? look.accent : "white"
  property string placeholder: "\u{f075a}"
  property real radius: Math.round(width * 0.24)

  readonly property var candidates: {
    if (Array.isArray(sources) && sources.length > 0) return sources
    return source !== "" ? [source] : []
  }
  readonly property string candidatesKey: candidates.join("\n")
  property int failed: 0
  onCandidatesKeyChanged: failed = 0

  readonly property string activeSource: candidates[failed] || ""
  readonly property bool isIcon: Notices.isIconSource(activeSource)
  readonly property bool isSymbolic: isIcon && Notices.isSymbolicIcon(activeSource)
  readonly property bool isLocalFile: activeSource.indexOf("file://") === 0
  readonly property bool loaded: activeSource !== "" && (isIcon ? icon.status : picture.status) === Image.Ready
  readonly property bool photoLoaded: !isIcon && picture.status === Image.Ready
  // Decoded at twice its size, so 1.25x to 2x screens get real pixels.
  readonly property int decodeSize: Math.max(64, Math.ceil(Math.max(width, height) * 2))

  function tryNext() {
    if (failed + 1 < candidates.length) failed++
  }

  // Tinted tile backdrop: shown while loading / as placeholder, and behind
  // monochrome symbolic icons. Hidden behind loaded opaque photos and
  // full-colour app icons so there is never a coloured halo or box behind them.
  Rectangle {
    anchors.fill: parent
    radius: cover.radius
    visible: !cover.loaded || cover.isSymbolic
    color: Util.alpha(cover.tint, 0.22)
  }

  Label {
    anchors.centerIn: parent
    visible: !cover.loaded
    look: cover.look
    mono: true
    size: 1
    font.pixelSize: Math.round(cover.height * 0.5)
    text: cover.placeholder
    color: cover.tint
    elide: Text.ElideNone
  }

  Image {
    id: icon
    anchors.fill: parent
    anchors.margins: cover.isSymbolic ? Math.round(cover.width * 0.18) : 0
    visible: cover.isIcon && status === Image.Ready && !cover.isSymbolic
    source: cover.isIcon ? cover.activeSource : ""
    fillMode: Image.PreserveAspectFit
    sourceSize.width: cover.decodeSize
    sourceSize.height: cover.decodeSize
    cache: !cover.isLocalFile
    asynchronous: true
    smooth: true
    mipmap: true
    onStatusChanged: if (status === Image.Error) cover.tryNext()
  }

  MultiEffect {
    anchors.fill: icon
    visible: cover.isSymbolic && icon.status === Image.Ready
    source: icon
    colorization: 1.0
    colorizationColor: cover.tint
  }

  ClippingRectangle {
    anchors.fill: parent
    visible: !cover.isIcon && picture.status === Image.Ready
    opacity: visible ? 1 : 0
    radius: cover.radius
    color: "transparent"

    Behavior on opacity {
      NumberAnimation { duration: cover.look ? cover.look.ms(140) : 140; easing.type: Easing.OutCubic }
    }

    Image {
      id: picture
      anchors.fill: parent
      source: cover.isIcon ? "" : cover.activeSource
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: cover.decodeSize
      sourceSize.height: cover.decodeSize
      cache: !cover.isLocalFile
      asynchronous: true
      smooth: true
      mipmap: true
      onStatusChanged: if (status === Image.Error) cover.tryNext()
    }
  }
}
