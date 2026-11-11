import QtQuick
import "../views"
import "../lib/Layout.js" as Layout

// Holds the island's views. Each one is built only while it is on screen
// or fading out, at its own final size, centred in the island; because a
// view never resizes with the shape, the shape reveals it rather than
// squashing it. A view fades and settles in once the shape has nearly
// reached its size, so nothing is drawn cut off by a shape still growing.
Item {
  id: host

  property var island: null
  // Whether the shape has (nearly) reached the current view's size.
  property bool settled: true
  readonly property var look: island.look
  readonly property var stage: island.stage

  // Which view each component draws.
  readonly property var catalog: ({
    "idle": restView, "idle-hover": restView, "hidden": null,
    "media": nowPlayingView, "recording": recordingView, "dictation": listeningView,
    "mic": inUseView, "inbox": bellView, "timer": timerView, "stopwatch": stopwatchView,
    "activity": liveView, "calendar": nextUpView,
    "hud-progress": levelView, "hud-label": statusView, "hud-track": trackView, "hud-toast": toastView,
    "notification": bannerView, "notification-actions": bannerView,
    "media-expanded": playerView, "recording-expanded": recordingOpenView,
    "recording-media-expanded": recordingOpenView, "dictation-expanded": dictationOpenView,
    "idle-expanded": homeView, "clock-expanded": clockOpenView, "activity-expanded": liveOpenView,
    "calendar-expanded": agendaView, "inbox-expanded": inboxView, "outputs-expanded": outputsView
  })

  Component { id: restView; Rest { island: host.island } }
  Component { id: nowPlayingView; NowPlaying { island: host.island } }
  Component { id: recordingView; Recording { island: host.island } }
  Component { id: listeningView; Listening { island: host.island } }
  Component { id: inUseView; InUse { island: host.island } }
  Component { id: bellView; Bell { island: host.island } }
  Component { id: timerView; Countdown { island: host.island } }
  Component { id: stopwatchView; Countdown { island: host.island; stopwatch: true } }
  Component { id: liveView; Live { island: host.island } }
  Component { id: nextUpView; NextUp { island: host.island } }
  Component { id: levelView; Level { island: host.island } }
  Component { id: statusView; Status { island: host.island } }
  Component { id: trackView; TrackCard { island: host.island } }
  Component { id: toastView; Toast { island: host.island } }
  Component { id: bannerView; Banner { island: host.island } }
  Component { id: playerView; Player { island: host.island } }
  Component { id: recordingOpenView; RecordingOpen { island: host.island } }
  Component { id: dictationOpenView; DictationOpen { island: host.island } }
  Component { id: homeView; Home { island: host.island } }
  Component { id: clockOpenView; ClockOpen { island: host.island } }
  Component { id: liveOpenView; LiveOpen { island: host.island } }
  Component { id: agendaView; Agenda { island: host.island } }
  Component { id: inboxView; InboxList { island: host.island } }
  Component { id: outputsView; Outputs { island: host.island } }

  Repeater {
    model: Layout.VIEWS.filter(function(name) { return host.catalog[name] })

    Item {
      id: slot
      required property string modelData
      readonly property string name: modelData
      readonly property bool resting: name === "idle" || name === "idle-hover"
      // The resting face follows the island's own size: the shape resizes
      // to fit it, so it never waits for the shape.
      readonly property bool on: host.stage.view === name && (resting || host.settled)
      readonly property var size: host.stage.shapeOf(name)

      width: resting ? host.width : host.look.s(size.w)
      height: resting ? host.height : host.look.s(size.h)
      x: host.look.snap((host.width - width) / 2)
      y: host.look.snap((host.height - height) / 2)
      opacity: on ? 1 : 0
      scale: on ? 1 : 0.96
      visible: opacity > 0.01
      enabled: on

      Behavior on opacity {
        NumberAnimation { duration: host.look.ms(slot.on ? 180 : 120); easing.type: Easing.OutCubic }
      }
      Behavior on scale {
        NumberAnimation { duration: host.look.ms(slot.on ? 180 : 120); easing.type: Easing.Bezier; easing.bezierCurve: host.look.easeOut }
      }

      Loader {
        anchors.fill: parent
        active: slot.visible || slot.on
        sourceComponent: host.catalog[slot.name]
      }
    }
  }
}
