import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// The island's window: a click-through layer-shell strip across the top of
// one monitor, holding the island's body, its status light, its views, the
// split-off bubble and (optionally) a glow in the music's colour. Only the
// island and the bubble take the pointer.
PanelWindow {
  id: win

  property var island: null
  readonly property var look: island.look
  readonly property var stage: island.stage
  readonly property var settings: island.settings

  // ---- where
  readonly property var targetScreen: {
    // Qt offers an unnamed placeholder when the last output goes away, and
    // Hyprland can briefly show its FALLBACK output while reconnecting.
    var screens = Quickshell.screens.filter(function(s) { return s.name !== "" && s.name !== "FALLBACK" })
    if (screens.length === 0) return null
    var wanted = settings.monitor
    if (wanted === "focused" && Hyprland.focusedMonitor) wanted = Hyprland.focusedMonitor.name
    return screens.filter(function(s) { return s.name === wanted })[0] || screens[0]
  }

  screen: targetScreen
  visible: guard.ready
  color: "transparent"
  anchors { top: true; left: true; right: true }
  // Tall enough for the biggest view (a full inbox or list of outputs).
  implicitHeight: look.s(360) + topMargin

  readonly property int topMargin: settings.notch ? 0 : look.s(settings.topMargin)

  WlrLayershell.namespace: "dynamic-island"
  WlrLayershell.layer: settings.overlayLayer ? WlrLayer.Overlay : WlrLayer.Top
  // The keyboard only while the calendar's link field is up (typing and
  // Ctrl+V go straight in; Esc gives it back). Otherwise the island never
  // takes focus from the app in front.
  WlrLayershell.keyboardFocus: stage.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: settings.reserveSpace ? ExclusionMode.Normal : ExclusionMode.Ignore
  exclusiveZone: settings.reserveSpace ? look.s(32) + topMargin : 0

  Shortcut {
    sequence: "Escape"
    enabled: win.stage.typing
    onActivated: win.stage.calendarAdding = false
  }

  mask: Region {
    item: body
    Region { item: bubble; intersection: Intersection.Combine }
  }

  SurfaceGuard {
    id: guard
    window: win
    targetScreen: win.targetScreen
  }

  Binding {
    target: win.look
    property: "devicePixelRatio"
    value: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1
  }

  // ---- the status light's state
  readonly property var lipState: {
    var v = stage.view
    var hud = island.hud.current
    var clocks = island.clocks
    var item = island.activities.current
    if (v === "hud-progress" && hud)
      return { tone: look.tone(hud.tone || "fg"), level: 0.95, progress: Math.min(1, Math.max(0, Number(hud.value) || 0)) }
    if (v === "timer" || (v === "clock-expanded" && clocks.timerActive))
      return { tone: look.orange, level: clocks.timerPaused ? 0.35 : 0.95, progress: 1 - clocks.timerProgress }
    if (v === "stopwatch" || v === "clock-expanded")
      return { tone: look.accent, level: clocks.stopwatchRunning ? 0.8 : 0.3, pulse: clocks.stopwatchRunning, period: 2000 }
    if (v.indexOf("recording") === 0)
      return { tone: look.urgent, level: 0.95, pulse: true, period: 1600 }
    if (v === "dictation" || v === "dictation-expanded")
      return { tone: island.dictation.listening ? look.urgent : look.accent, level: 0.9, pulse: true,
               period: island.dictation.listening ? 1600 : 1000 }
    if ((v === "activity" || v === "activity-expanded") && item)
      return item.progress >= 0 ? { tone: look.tone(item.color), level: 0.95, progress: item.progress }
                                : { tone: look.tone(item.color), level: 0.8, pulse: true, period: 1800 }
    if (v === "media" || v === "hud-track" || v === "media-expanded")
      return { tone: island.media.tint, level: island.media.playing ? (v === "media-expanded" ? 0.6 : 0.9) : 0.25,
               pulse: island.media.playing, period: 900 }
    if (v === "notification" || v === "notification-actions")
      return { tone: stage.banner && stage.banner.critical ? look.urgent : look.accent, level: 0.55 }
    if ((v === "hud-label" || v === "hud-toast") && hud)
      return { tone: look.tone(hud.tone || "accent"), level: 0.85 }
    if (v === "mic")
      return { tone: island.privacy.cameraInUse ? look.green : look.orange, level: 0.85, pulse: true, period: 2400 }
    if (v === "calendar")
      return { tone: look.accent, level: 0.85, pulse: true, period: 2400 }
    if (v === "inbox")
      return { tone: look.accent, level: 0.6 }
    if (stage.resting)
      return { tone: look.accent, level: v === "idle-hover" ? 0.6 : 0.32 }
    return { tone: look.accent, level: 0.2 }
  }

  Item {
    id: stage_
    anchors.fill: parent

    // Inspects browser temp MPRIS art files (e.g. /tmp/.com.google.Chrome.XXXX)
    // inside the PanelWindow where Canvas.available is true, distinguishing
    // opaque album art from transparent browser logos.
    Image {
      id: browserArtMeasure
      visible: false
      cache: false
      asynchronous: true
      source: win.island.media.isBrowserArt ? win.island.media.rawArtUrl : ""
      onStatusChanged: {
        var url = win.island.media.rawArtUrl
        if (!win.island.media.isBrowserArt || !url) return
        if (status === Image.Error) win.island.media.reportBrowserArt(url, 0, 0, null)
        else if (status === Image.Ready) browserArtProbe.inspect(url)
      }
    }

    Canvas {
      id: browserArtProbe
      width: 16
      height: 16
      opacity: 0
      enabled: false
      renderTarget: Canvas.Image
      property string pendingUrl: ""

      function inspect(url) {
        if (!url) return
        pendingUrl = url
        if (!available) return
        if (isImageLoaded(url)) unloadImage(url)
        loadImage(url)
      }

      onAvailableChanged: {
        if (available && pendingUrl !== "" && pendingUrl === win.island.media.rawArtUrl)
          inspect(pendingUrl)
      }

      onImageLoaded: {
        var url = pendingUrl
        if (!url || url !== win.island.media.rawArtUrl) return
        if (isImageError(url)) {
          win.island.media.reportBrowserArt(url, 0, 0, null)
          return
        }
        var w = browserArtMeasure.implicitWidth
        var h = browserArtMeasure.implicitHeight
        var alphas = null
        if (available) {
          var ctx = getContext("2d")
          if (ctx) {
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(url, 0, 0, width, height)
            var d = ctx.getImageData(0, 0, width, height).data
            if (d && d.length >= width * height * 4) {
              alphas = [
                d[3],
                d[(width - 1) * 4 + 3],
                d[((height - 1) * width) * 4 + 3],
                d[(height * width - 1) * 4 + 3]
              ]
            }
          }
        }
        win.island.media.reportBrowserArt(url, w, h, alphas)
        unloadImage(url)
      }
    }

    // The body's size follows the current view's: a quick ease-out, the
    // shell's motion, instead of a spring.
    property real w: win.look.s(win.stage.target.w)
    property real h: win.look.s(win.stage.target.h)
    property real r: win.look.s(win.stage.target.r)

    Behavior on w { NumberAnimation { duration: win.look.ms(260); easing.type: Easing.Bezier; easing.bezierCurve: win.look.easeOut } }
    Behavior on h { NumberAnimation { duration: win.look.ms(260); easing.type: Easing.Bezier; easing.bezierCurve: win.look.easeOut } }
    Behavior on r { NumberAnimation { duration: win.look.ms(260); easing.type: Easing.Bezier; easing.bezierCurve: win.look.easeOut } }

    readonly property bool settled: Math.abs(w - win.look.s(win.stage.target.w)) < win.look.s(18)
      && Math.abs(h - win.look.s(win.stage.target.h)) < win.look.s(12)

    // The fillets that blend a notch into the screen's edge.
    readonly property real ear: win.look.s(9)

    // Notch style: the body and its two concave ears are one outline, so
    // there is no seam where pieces would meet, and every point is on the
    // device pixel grid so edges stay crisp at 1.25x and 1.5x.
    Shape {
      id: notchShape
      visible: win.settings.notch && body.width > stage_.ear * 2
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      readonly property real e: stage_.ear
      readonly property real x0: body.x
      readonly property real x1: body.x + body.width
      readonly property real h: body.height
      readonly property real r: Math.max(0, Math.min(body.radius, h - e, body.width / 2))

      NotchOutline {
        left: notchShape.x0; right: notchShape.x1; depth: notchShape.h; corner: notchShape.r; ear: notchShape.e
        strokeColor: "transparent"
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: 0; y2: notchShape.h
          GradientStop { position: 0; color: win.look.bodyTop }
          GradientStop { position: 1; color: win.look.bodyBottom }
        }
        PathLine { x: notchShape.x0 - notchShape.e; y: 0 }
      }

      // The rim: the sides and lip catch a hairline of light; the top is
      // the screen's edge, so it stays open.
      NotchOutline {
        left: notchShape.x0; right: notchShape.x1; depth: notchShape.h; corner: notchShape.r; ear: notchShape.e
        fillColor: "transparent"
        strokeColor: win.look.rim
        strokeWidth: 1
      }
    }

    // Floating style: the same body as a capsule, rim all the way round.
    Shape {
      visible: !win.settings.notch && body.width > 4
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeColor: win.look.rim
        strokeWidth: 1
        fillGradient: LinearGradient {
          x1: 0; y1: body.y; x2: 0; y2: body.y + body.height
          GradientStop { position: 0; color: win.look.bodyTop }
          GradientStop { position: 1; color: win.look.bodyBottom }
        }
        PathRectangle {
          x: body.x + 0.5; y: body.y + 0.5
          width: Math.max(0, body.width - 1); height: Math.max(0, body.height - 1)
          radius: Math.max(0, body.radius - 0.5)
        }
      }
    }

    // A soft light behind the island in the music's colour while it plays
    // ("glow": true). Only this goes through a blur; the body never does.
    Rectangle {
      id: glow
      readonly property bool lit: win.settings.glow && win.island.media.playing
        && ["media", "media-expanded", "hud-track"].indexOf(win.stage.view) !== -1
      x: body.x - win.look.s(4)
      y: body.y + win.look.s(2)
      width: body.width + win.look.s(8)
      height: body.height + win.look.s(2)
      radius: body.radius
      color: win.island.media.tint
      opacity: lit ? breath : 0
      visible: opacity > 0.01
      property real breath: 0.5

      Behavior on opacity { NumberAnimation { duration: win.look.ms(240); easing.type: Easing.OutCubic } }

      SequentialAnimation on breath {
        running: glow.lit && !win.look.still
        loops: Animation.Infinite
        NumberAnimation { to: 0.28; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.55; duration: 1600; easing.type: Easing.InOutSine }
      }

      layer.enabled: visible
      layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 40; autoPaddingEnabled: true }
    }

    // The island itself: a plain rectangle that clips by scissor (an
    // offscreen layer would soften everything inside at fractional scales)
    // and holds the content. The shapes above paint it.
    Rectangle {
      id: body
      x: win.look.snap((stage_.width - width) / 2)
      y: win.look.snap(win.topMargin)
      width: win.look.snap(Math.max(0, stage_.w))
      height: win.look.snap(Math.max(0, stage_.h))
      radius: Math.max(0, Math.min(stage_.r, height / 2, width / 2))
      color: "transparent"
      clip: true
      opacity: width < 4 ? 0 : 1
      scale: press.pressed ? 0.97 : 1
      transformOrigin: Item.Top

      Behavior on scale { NumberAnimation { duration: win.look.ms(120); easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: win.look.ms(120); easing.type: Easing.OutCubic } }

      HoverHandler {
        onHoveredChanged: win.stage.hovered = hovered
      }

      MouseArea {
        id: press
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { win.stage.clicked(mouse.button) }
        onWheel: function(wheel) { win.island.sound.nudge(wheel.angleDelta.y) }
      }

      // Along the lip, clear of the rounded corners.
      Lip {
        readonly property real inset: Math.min(body.radius, body.height / 2) * 0.85 + win.look.s(6)
        x: win.look.snap(inset)
        width: Math.max(0, body.width - inset * 2)
        height: Math.max(2, win.look.snap(win.look.s(2)))
        y: win.look.snap(body.height - height - win.look.s(2))
        look: win.look
        tone: win.lipState.tone
        level: win.lipState.level
        progress: win.lipState.progress === undefined ? -1 : win.lipState.progress
        pulse: win.lipState.pulse === true
        period: win.lipState.period || 1400
        sweeps: win.island.sweeps
      }

      ViewHost {
        width: body.width
        height: body.height
        island: win.island
        settled: stage_.settled
      }
    }

    // The second live activity, in its own circle beside the island.
    Rectangle {
      id: bubble

      readonly property real d: win.look.s(32)
      readonly property bool shown: win.stage.showBubble

      width: d
      height: d
      radius: d / 2
      y: win.settings.notch ? win.look.s(4) : win.topMargin
      x: shown ? body.x + body.width + win.look.s(8) : body.x + body.width - d
      gradient: Gradient {
        GradientStop { position: 0; color: win.look.bodyTop }
        GradientStop { position: 1; color: win.look.bodyBottom }
      }
      border.width: 1
      border.color: win.look.rim
      opacity: shown ? 1 : 0
      scale: shown ? 1 : 0.96
      visible: opacity > 0.01
      clip: true

      Behavior on x { NumberAnimation { duration: win.look.ms(260); easing.type: Easing.Bezier; easing.bezierCurve: win.look.easeOut } }
      Behavior on opacity { NumberAnimation { duration: win.look.ms(bubble.shown ? 180 : 120); easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: win.look.ms(180); easing.type: Easing.OutCubic } }

      BubbleFace {
        anchors.fill: parent
        island: win.island
        kind: win.stage.secondary
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: win.stage.bubbleClicked()
      }
    }
  }
}
