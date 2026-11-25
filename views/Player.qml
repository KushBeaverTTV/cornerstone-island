import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../ui"
import "../lib/Format.js" as Format
import "../lib/Glyphs.js" as Glyphs

// The full player: the cover washed softly behind everything, the song,
// a seekable bar with elapsed and remaining time, transport controls, a
// per-source volume slider with mute toggle, and the output picker.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var media: island.media
  readonly property int pad: look.s(22)
  readonly property real corner: look.s(42)

  // The wash: the loaded cover, tiny, blurred and desaturated, painted into a
  // shape with the island's own corners so only the backdrop is soft and the
  // edges stay crisp.
  Image {
    id: washSource
    visible: false
    width: view.width
    height: view.height
    source: art.photoLoaded ? art.activeSource : ""
    cache: art.activeSource.indexOf("file://") !== 0
    sourceSize.width: 96
    sourceSize.height: 96
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }

  MultiEffect {
    id: washBlur
    width: view.width
    height: view.height
    source: washSource
    blurEnabled: true
    blur: 1.0
    blurMax: 64
    saturation: 0.45
  }

  ShaderEffectSource {
    id: washTexture
    sourceItem: washBlur
    hideSource: true
    visible: false
  }

  Shape {
    anchors.fill: parent
    visible: washSource.status === Image.Ready
    opacity: 0.42
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillItem: washTexture
      PathRectangle {
        x: 0; y: 0; width: view.width; height: view.height
        topLeftRadius: view.island.settings.notch ? 0 : view.corner
        topRightRadius: view.island.settings.notch ? 0 : view.corner
        bottomLeftRadius: view.corner
        bottomRightRadius: view.corner
      }
    }
  }

  // The cover and the song open the app that is playing.
  Rectangle {
    id: source
    x: art.x - view.look.s(6)
    y: art.y - view.look.s(6)
    width: bars.x - view.look.s(8) - x
    height: art.height + view.look.s(12)
    radius: view.look.s(14)
    color: sourceMouse.containsMouse && view.media.canShow ? view.look.fgFaint : "transparent"
    Behavior on color { ColorAnimation { duration: view.look.ms(120) } }

    MouseArea {
      id: sourceMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: view.media.canShow
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        view.media.showWindow()
        view.island.stage.collapse()
      }
    }
  }

  Cover {
    id: art
    x: view.pad
    y: view.look.s(20)
    width: view.look.s(58)
    height: width
    look: view.look
    sources: view.media.coverSources
  }

  // Subtle app badge on the corner of the album art showing which app is playing.
  Rectangle {
    visible: art.photoLoaded && view.media.appIcon !== ""
    width: view.look.s(20)
    height: width
    radius: width / 2
    x: art.x + art.width - width + view.look.s(4)
    y: art.y + art.height - height + view.look.s(4)
    color: view.look.bodyAt(0.35)
    border.width: Math.max(1, view.look.s(1.5))
    border.color: view.look.bodyAt(0.35)

    Cover {
      anchors.fill: parent
      anchors.margins: view.look.s(2)
      radius: width / 2
      look: view.look
      source: view.media.appIcon
      placeholder: ""
    }
  }

  Bars {
    id: bars
    anchors.right: parent.right
    anchors.rightMargin: view.pad + view.look.s(2)
    anchors.verticalCenter: art.verticalCenter
    look: view.look
    playing: view.media.playing
    color: view.media.tint
    barWidth: view.look.s(3)
    maxHeight: view.look.s(20)
  }

  Headline {
    anchors.left: art.right
    anchors.leftMargin: view.look.s(14)
    anchors.right: bars.left
    anchors.rightMargin: view.look.s(14)
    anchors.verticalCenter: art.verticalCenter
    look: view.look
    titleSize: 15
    detailSize: 13
    spacing: view.look.s(3)
    title: view.media.title || "Not playing"
    detail: view.media.artist
  }

  // Keep the island open while dragging either slider.
  Binding {
    target: view.island.stage
    property: "interacting"
    value: seekMeter.dragging || volumeMeter.dragging
  }
  Component.onDestruction: if (view.island && view.island.stage) view.island.stage.interacting = false

  // Elapsed, seek bar, remaining.
  Item {
    id: timeline
    x: view.pad
    y: art.y + art.height + view.look.s(14)
    width: parent.width - view.pad * 2
    height: view.look.s(16)
    visible: view.media.length > 0

    Label {
      id: elapsed
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      mono: true
      size: 11
      text: Format.clock(view.media.position)
      color: view.look.fgDim
    }

    Label {
      id: remaining
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      mono: true
      size: 11
      text: "-" + Format.clock(view.media.length - view.media.position)
      color: view.look.fgDim
    }

    Meter {
      id: seekMeter
      anchors.left: elapsed.right
      anchors.leftMargin: view.look.s(10)
      anchors.right: remaining.left
      anchors.rightMargin: view.look.s(10)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      look: view.look
      thickness: view.look.s(5)
      value: view.media.length > 0 ? view.media.position / view.media.length : 0
      shaded: true
      knob: true
      seekable: view.media.canSeek
      onSeek: function(fraction) { view.media.seek(fraction) }
    }
  }

  // Multi-player switcher when 2+ players are loaded (e.g. Chrome + Spotify).
  Row {
    visible: view.media.playerCount > 1
    anchors.left: parent.left
    anchors.leftMargin: view.pad - view.look.s(4)
    anchors.verticalCenter: transport.verticalCenter
    spacing: view.look.s(2)

    RoundButton {
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(22)
      height: width
      look: view.look
      glyph: Glyphs.CHEVRON_LEFT
      glyphSize: 12
      color: view.look.fgDim
      onClicked: view.media.cyclePlayer(-1)
    }

    Label {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      mono: true
      size: 10
      text: (view.media.playerIndex + 1) + "/" + view.media.playerCount
      color: view.look.fgDim
    }

    RoundButton {
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(22)
      height: width
      look: view.look
      glyph: Glyphs.CHEVRON_RIGHT
      glyphSize: 12
      color: view.look.fgDim
      onClicked: view.media.cyclePlayer(1)
    }
  }

  // Transport controls, centred between the timeline (or cover) and the volume row.
  Row {
    id: transport
    readonly property real topEdge: timeline.visible ? (timeline.y + timeline.height) : (art.y + art.height)
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round(topEdge + (volumeRow.y - topEdge - height) / 2)
    spacing: view.look.s(26)

    RoundButton {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      glyph: Glyphs.PREVIOUS
      glyphSize: 22
      available: view.media.canPrevious
      onClicked: view.media.previous()
    }

    // Play and pause is the one solid control: a disc in the text colour.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(44)
      height: width
      radius: width / 2
      color: view.look.fg
      scale: playMouse.pressed ? 0.92 : 1

      Behavior on scale { NumberAnimation { duration: view.look.ms(120); easing.type: Easing.OutCubic } }

      Label {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: view.media.playing ? 0 : view.look.s(1)
        look: view.look
        mono: true
        size: 22
        elide: Text.ElideNone
        text: view.media.playing ? Glyphs.PAUSE : Glyphs.PLAY
        color: view.look.bodyAt(0.5)
      }

      MouseArea {
        id: playMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: view.media.toggle()
      }
    }

    RoundButton {
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      glyph: Glyphs.NEXT
      glyphSize: 22
      available: view.media.canNext
      onClicked: view.media.next()
    }
  }

  // Per-source volume control (mute button, draggable/scrollable slider, level)
  // alongside the "Play on" output picker.
  Item {
    id: volumeRow
    x: view.pad - view.look.s(4)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.look.s(14)
    width: parent.width - (view.pad - view.look.s(4)) * 2
    height: view.look.s(28)

    RoundButton {
      id: muteButton
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(28)
      height: width
      look: view.look
      glyph: Glyphs.volume(view.media.sourceVolume, view.media.sourceMuted)
      glyphSize: 15
      color: view.media.sourceMuted ? view.look.fgDim : view.look.fg
      available: view.media.canVolume
      onClicked: view.media.toggleSourceMute()
    }

    RoundButton {
      id: outputButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(28)
      height: width
      look: view.look
      glyph: view.island.sound.glyph(view.island.sound.sink)
      glyphSize: 15
      color: view.look.fgDim
      onClicked: view.island.stage.openOutputs()
    }

    Label {
      id: volumeReadout
      anchors.right: outputButton.left
      anchors.rightMargin: view.look.s(8)
      anchors.verticalCenter: parent.verticalCenter
      width: view.look.s(34)
      horizontalAlignment: Text.AlignRight
      look: view.look
      mono: true
      size: 11
      text: !view.media.canVolume ? "--" : (view.media.sourceMuted ? "Mute" : Math.round(view.media.sourceVolume * 100) + "%")
      color: view.look.fgDim
      opacity: view.media.canVolume ? 1 : 0.45
    }

    Meter {
      id: volumeMeter
      anchors.left: muteButton.right
      anchors.leftMargin: view.look.s(6)
      anchors.right: volumeReadout.left
      anchors.rightMargin: view.look.s(8)
      anchors.verticalCenter: parent.verticalCenter
      height: view.look.s(20)
      look: view.look
      thickness: view.look.s(5)
      value: view.media.sourceMuted ? 0 : view.media.sourceVolume
      color: view.media.sourceMuted ? view.look.fgDim : view.look.fg
      shaded: true
      knob: view.media.canVolume
      seekable: view.media.canVolume
      liveDrag: true
      wheelEnabled: view.media.canVolume
      opacity: view.media.canVolume ? 1 : 0.35
      onSeek: function(fraction) { view.media.setSourceVolume(fraction) }
      onWheeled: function(delta) { view.media.nudgeSourceVolume(delta) }
    }
  }
}
