import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../lib/Players.js" as Players
import "../lib/Format.js" as Format

// What is playing, from MPRIS: the player the island follows, its track,
// cover, position and transport. A demo can stand in for the player.
Item {
  id: media

  property var island: null

  // undefined: follow the real players. null: act as if nothing plays.
  // An object { playing, title, artist, art, length }: a pretend player.
  property var stand: undefined
  readonly property bool standing: stand !== undefined
  readonly property var fake: standing && stand ? stand : null

  // ---- the player
  readonly property var players: Mpris.players ? Mpris.players.values : []
  property string followed: ""
  // Bumped when a player's track or state changes, so `player` is re-chosen.
  property int revision: 0
  readonly property var player: { revision; return Players.choose(players, followed) }

  // Keep following the shown player across a pause. Deferred, so the write
  // does not land inside the evaluation of `player` itself.
  onPlayerChanged: Qt.callLater(function() { if (media.player) media.followed = Players.idOf(media.player) })

  Instantiator {
    model: media.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() {
        // A player that starts playing takes the island over, unless it is
        // only a poorer copy of a song another player shows already.
        if (modelData.isPlaying && Players.eligible(media.players).indexOf(modelData) !== -1)
          media.followed = Players.idOf(modelData)
        media.revision++
      }
      function onTrackTitleChanged() { media.revision++ }
      function onTrackArtistChanged() { media.revision++ }
      function onTrackArtUrlChanged() { media.revision++ }
    }
  }

  // ---- the track
  readonly property bool present: standing ? fake !== null : player !== null
  readonly property bool playing: fake ? fake.playing === true : (!standing && !!player && player.isPlaying)
  readonly property string title: fake ? String(fake.title || "") : (player && !standing ? String(player.trackTitle || "") : "")
  readonly property string artist: fake ? String(fake.artist || "") : (player && !standing ? String(player.trackArtist || "") : "")
  readonly property real length: fake ? Number(fake.length) || 0
    : (player && !standing && player.lengthSupported ? player.length : 0)
  readonly property bool canSeek: !standing && !!player && player.canSeek && player.positionSupported
  readonly property bool canNext: fake ? true : (!standing && !!player && player.canGoNext)
  readonly property bool canPrevious: fake ? true : (!standing && !!player && player.canGoPrevious)
  property real position: 0

  // The cover: the player's own, at the best size its CDN offers; for a
  // player with no real cover (browser video), one looked up by title.
  readonly property bool hasOwnCover: !!player && !standing && Players.hasCover(player.trackArtUrl)
  readonly property string cover: fake ? String(fake.art || "")
    : (hasOwnCover ? Players.sharpCover(player.trackArtUrl) : (present ? artwork.url : ""))

  Artwork {
    id: artwork
    query: media.present && !media.standing && !media.hasOwnCover ? Players.posterQuery(media.settledTitle) : ""
  }

  // ---- live activity: kept up a while after pausing, like iOS, so a
  // quick pause does not make the island collapse and open again.
  property bool lingering: false
  readonly property bool live: present && (playing || lingering || fake !== null)

  onPlayingChanged: {
    if (!playing && present && island.settings.mediaLingerMs > 0) {
      lingering = true
      lingerTimer.interval = island.settings.mediaLingerMs
      lingerTimer.restart()
    }
  }
  Timer { id: lingerTimer; onTriggered: media.lingering = false }

  // ---- transport
  function toggle() {
    if (fake) stand = Object.assign({}, fake, { playing: !fake.playing })
    else if (player && !standing && player.canTogglePlaying) player.togglePlaying()
  }

  function next() {
    if (fake) position = 0
    else if (player && !standing && player.canGoNext) player.next()
  }

  function previous() {
    if (fake) position = 0
    else if (player && !standing && player.canGoPrevious) player.previous()
  }

  function seek(fraction) {
    if (!canSeek || length <= 0) return
    var to = Format.clamp01(fraction) * length
    player.position = to
    position = to
  }

  // MPRIS does not push the position; read it while the player view shows it.
  Timer {
    interval: 500
    repeat: true
    triggeredOnStart: true
    running: media.present && !!media.island && media.island.stage.view === "media-expanded"
    onTriggered: {
      if (media.fake) {
        if (media.fake.playing) media.position = (media.position + 0.5) % Math.max(1, media.length)
      } else if (media.player && !media.standing && media.player.positionSupported) {
        media.player.positionChanged()
        media.position = media.player.position
      }
    }
  }

  // ---- track changes: a short now-playing card. Players send title and
  // artist as separate updates, so it waits for them to settle.
  readonly property string signature: title + "\u0001" + artist
  property string announced: ""
  // The title once it has settled, for the artwork lookup.
  property string settledTitle: ""
  onSignatureChanged: settleTimer.restart()

  // A demo swaps the track without it being news.
  function quietly() { Qt.callLater(function() { media.announced = media.signature }) }

  Timer {
    id: settleTimer
    interval: 450
    onTriggered: {
      media.settledTitle = media.title
      if (media.signature === media.announced) return
      media.announced = media.signature
      if (media.island.ready && media.island.settings.showTrackChange && media.playing
          && media.title !== "" && !media.island.stage.open)
        media.island.hud.show({ key: "track", layout: "track", duration: 3200 })
    }
  }

  // ---- tint: the theme accent, or with "visualizerColor": "artwork" the
  // most vivid colour of the cover. It colours the equaliser and the glow.
  ColorQuantizer {
    id: quantizer
    source: media.island.settings.artworkTint && media.cover ? media.cover : ""
    depth: 3
    rescaleSize: 64
  }

  readonly property color tint: {
    var accent = island.look.accent
    if (!island.settings.artworkTint) return accent
    var best = null
    var bestScore = 0.12
    var colors = quantizer.colors || []
    for (var i = 0; i < colors.length; i++) {
      var c = colors[i]
      var score = c.hsvValue < 0.35 ? 0 : c.hsvSaturation * c.hsvValue
      if (score > bestScore) { best = c; bestScore = score }
    }
    return best ? Qt.hsva(best.hsvHue, Math.max(0.45, best.hsvSaturation), Math.max(0.75, best.hsvValue), 1) : accent
  }
}
