import QtQuick
import Quickshell.Widgets
import qs.Commons

// A picture in a rounded tile: album covers, posters, notification images.
// A tinted glyph stands in until it loads, and stays if it never does.
// Covers are cropped from the centre (posters keep their faces); app icons
// from the icon theme have their own shape, so they are drawn whole.
Item {
  id: cover

  property var look: null
  property string source: ""
  property color tint: look ? look.accent : "white"
  property string placeholder: "\u{f075a}"
  property real radius: Math.round(width * 0.24)

  readonly property bool isIcon: source.indexOf("image://icon/") === 0
  readonly property bool loaded: (isIcon ? icon.status : picture.status) === Image.Ready
  // Decoded at twice its size, so 1.25x to 2x screens get real pixels.
  readonly property int decodeSize: Math.max(64, Math.ceil(Math.max(width, height) * 2))

  Rectangle {
    anchors.fill: parent
    radius: cover.radius
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
    visible: cover.isIcon
    source: cover.isIcon ? cover.source : ""
    fillMode: Image.PreserveAspectFit
    sourceSize.width: cover.decodeSize
    sourceSize.height: cover.decodeSize
    asynchronous: true
    smooth: true
    mipmap: true
  }

  ClippingRectangle {
    anchors.fill: parent
    visible: !cover.isIcon && picture.status === Image.Ready
    radius: cover.radius
    color: "transparent"

    Image {
      id: picture
      anchors.fill: parent
      source: cover.isIcon ? "" : cover.source
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: cover.decodeSize
      sourceSize.height: cover.decodeSize
      asynchronous: true
      smooth: true
      mipmap: true
    }
  }
}
