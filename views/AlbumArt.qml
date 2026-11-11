import QtQuick
import QtQuick.Effects
import qs.Commons

// Rounded cover art with a tinted glyph standing in until (or unless) the
// player provides an image.
//
// Cropping history, learned the hard way: painting the image into a rounded
// Shape via fillItem cannot crop at all -- the fill stretches the whole
// texture into the tile (portrait posters came out squashed), and the
// square-sourceSize decode that was supposed to pre-crop the texture clips
// from the top-left instead of the center (posters showed their top corner:
// a starship and the top of a head, never the faces). A plain Image with
// PreserveAspectCrop crops centered, so the picture is a masked Image now
// and the Shape machinery is gone. Verified against synthetic quadrant
// targets on a headless output: this renders the true center crop.
Item {
  id: art

  property string source: ""
  property color tint: Color.accent
  property string fontFamily: Style.font.family
  property real radius: Math.round(width * 0.24)
  property string placeholder: "󰝚"

  // App icons from the icon theme have their own shape (and transparency),
  // so they are drawn as-is instead of cropped into a rounded tile.
  readonly property bool themeIcon: source.indexOf("image://icon/") === 0

  // Decode at twice the on-screen size so 1.25x/1.5x/2x screens all get
  // real pixels; the scene graph filters it down smoothly.
  readonly property int decodeSize: Math.max(64, Math.ceil(Math.max(width, height) * 2))

  // Tinted backdrop, always there; the glyph shows through until the cover
  // loads (and stays if it never does).
  Rectangle {
    anchors.fill: parent
    radius: art.radius
    color: Util.alpha(art.tint, 0.22)
  }

  Text {
    anchors.centerIn: parent
    visible: image.status !== Image.Ready && picImage.status !== Image.Ready
    text: art.placeholder
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: art.fontFamily
    font.pixelSize: Math.round(art.height * 0.5)
    color: art.tint
  }

  // Theme icons: drawn plainly, as before.
  Image {
    id: image
    anchors.fill: parent
    visible: art.themeIcon
    source: art.themeIcon ? art.source : ""
    fillMode: Image.PreserveAspectFit
    sourceSize.width: art.decodeSize
    sourceSize.height: art.decodeSize
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
  }

  // Covers: a centered crop, rounded by a mask.
  Item {
    id: pic
    anchors.fill: parent
    visible: !art.themeIcon
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: picMask
    }

    Rectangle {
      id: picMask
      width: art.width
      height: art.height
      radius: art.radius
      visible: false
      layer.enabled: true
    }

    Image {
      id: picImage
      width: art.width
      height: art.height
      source: art.themeIcon ? "" : art.source
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: art.decodeSize
      sourceSize.height: art.decodeSize
      asynchronous: true
      cache: true
      smooth: true
      mipmap: true
    }
  }
}
