import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../lib/Players.js" as Players
import "../lib/Format.js" as Format
import "../lib/Scripts.js" as Scripts

// What is playing, from MPRIS: the player the island follows, its track,
// cover art, per-source volume (from PipeWire or MPRIS), app icon, position
// and transport. A demo can stand in for the player.
Item {
  id: media

  property var island: null

  // undefined: follow the real players. null: act as if nothing plays.
  // An object { playing, title, artist, album, art, length, volume, muted }: a pretend player.
  property var stand: undefined
  readonly property bool standing: stand !== undefined
  readonly property var fake: standing && stand ? stand : null

  // ---- the player
  readonly property var players: Mpris.players ? Mpris.players.values : []
  property string followed: ""
  // Bumped when a player's track or state changes, so `player` is re-chosen.
  property int revision: 0
  readonly property var eligiblePlayers: { revision; return Players.eligible(players) }
  readonly property var player: { revision; return Players.choose(players, followed) }
  readonly property int playerCount: fake ? 1 : eligiblePlayers.length
  readonly property int playerIndex: {
    if (fake || !player) return 0
    var idx = eligiblePlayers.indexOf(player)
    return idx >= 0 ? idx : 0
  }

  function cyclePlayer(delta) {
    if (standing || eligiblePlayers.length < 2) return
    var next = (playerIndex + (delta >= 0 ? 1 : -1) + eligiblePlayers.length) % eligiblePlayers.length
    followed = Players.idOf(eligiblePlayers[next])
    revision++
  }

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
      function onTrackAlbumChanged() { media.revision++ }
      function onTrackArtUrlChanged() { media.revision++ }
    }
  }

  // ---- the track
  readonly property bool present: standing ? fake !== null : player !== null
  readonly property bool playing: fake ? fake.playing === true : (!standing && !!player && player.isPlaying)
  readonly property string title: fake ? String(fake.title || "") : (player && !standing ? String(player.trackTitle || "") : "")
  readonly property string artist: fake ? String(fake.artist || "") : (player && !standing ? String(player.trackArtist || "") : "")
  readonly property string album: fake ? String(fake.album || "") : (player && !standing ? String(player.trackAlbum || "") : "")
  readonly property real length: fake ? Number(fake.length) || 0
    : (player && !standing && player.lengthSupported ? player.length : 0)
  readonly property bool canSeek: !standing && !!player && player.canSeek && player.positionSupported
  readonly property bool canNext: fake ? true : (!standing && !!player && player.canGoNext)
  readonly property bool canPrevious: fake ? true : (!standing && !!player && player.canGoPrevious)
  property real position: 0

  // ---- app icon for the playing source (badge and last-resort cover fallback)
  readonly property string appName: fake ? String(fake.app || "")
    : (player && !standing ? String(player.identity || player.desktopEntry || "") : "")

  readonly property string appIcon: {
    if (standing || !player) return ""
    var appsRev = DesktopEntries.applications.values.length
    var names = Players.playerIconCandidates(player)
    for (var i = 0; i < names.length; i++) {
      var themed = Quickshell.iconPath(names[i], true)
      if (themed) return themed
    }
    for (var j = 0; j < names.length; j++) {
      var d = DesktopEntries.byId(names[j]) || DesktopEntries.heuristicLookup(names[j])
      if (d && d.icon) {
        var icon = String(d.icon)
        if (icon.charAt(0) === "/") return "file://" + icon
        var path = Quickshell.iconPath(icon, true)
        if (path) return path
      }
    }
    return ""
  }

  // ---- per-source volume: PipeWire playback stream(s) for the current player,
  // with MPRIS player.volume as fallback for non-browser players without an
  // active stream (e.g. remote/paused MPRIS player).
  property real fakeVolume: 0.72
  property bool fakeMuted: false
  property real preMuteVolume: 0.5

  readonly property var sourceStreams: (!standing && !!player && !!island && !!island.sound)
    ? Players.streamsForPlayer(player, island.sound.playbackStreams, players) : []
  readonly property var primaryStream: sourceStreams.length > 0 ? sourceStreams[0] : null
  readonly property bool hasStreamVolume: !!primaryStream && !!primaryStream.audio
  readonly property bool canMprisVolume: !standing && !!player && !!player.volumeSupported && !Players.isBrowser(player)
  readonly property bool canVolume: fake !== null || hasStreamVolume || canMprisVolume

  readonly property real sourceVolume: {
    if (fake) return fakeVolume
    if (hasStreamVolume) return Math.max(0, Number(primaryStream.audio.volume) || 0)
    if (canMprisVolume) return Math.max(0, Number(player.volume) || 0)
    return 0
  }

  readonly property bool sourceMuted: {
    if (fake) return fakeMuted
    if (hasStreamVolume) return !!primaryStream.audio.muted
    if (canMprisVolume) return sourceVolume <= 0.001
    return false
  }

  function setSourceVolume(fraction) {
    var v = Format.clamp01(fraction)
    if (fake) {
      fakeMuted = false
      fakeVolume = v
      return
    }
    if (sourceStreams.length > 0) {
      for (var i = 0; i < sourceStreams.length; i++) {
        var s = sourceStreams[i]
        if (s && s.audio) {
          s.audio.muted = false
          s.audio.volume = v
        }
      }
      return
    }
    if (canMprisVolume) player.volume = v
  }

  function toggleSourceMute() {
    if (fake) {
      fakeMuted = !fakeMuted
      return
    }
    if (sourceStreams.length > 0) {
      var next = !sourceMuted
      for (var i = 0; i < sourceStreams.length; i++) {
        var s = sourceStreams[i]
        if (s && s.audio) s.audio.muted = next
      }
      return
    }
    if (canMprisVolume) {
      if (sourceVolume > 0.001) {
        preMuteVolume = sourceVolume
        player.volume = 0
      } else {
        player.volume = preMuteVolume > 0.05 ? preMuteVolume : 0.5
      }
    }
  }

  function nudgeSourceVolume(wheelDelta) {
    if (!canVolume || wheelDelta === 0) return
    var base = sourceMuted ? 0 : sourceVolume
    setSourceVolume(base + (wheelDelta > 0 ? 0.05 : -0.05))
  }

  // ---- cover art:
  // 1. Direct player art (Spotify, SoundCloud, Apple Music, local files, etc.),
  //    upgraded to high-res CDN URL with the original URL kept as fallback.
  // 2. Browser temp files (/tmp/.com.google.Chrome.XXXX etc.) are inspected:
  //    opaque album art (YouTube Music, Spotify Web) shows immediately and
  //    attempts a strict high-res upgrade when small (<= 180 px); transparent
  //    square browser logos (Prime Video / no-art tabs) are rejected so online
  //    lookup fetches the real cover/poster instead.
  readonly property string rawArtUrl: (!standing && player && player.trackArtUrl) ? String(player.trackArtUrl) : ""
  readonly property bool isBrowserArt: Players.isBrowserTempArt(rawArtUrl)

  // Classification of the current `rawArtUrl` when `isBrowserArt`:
  // "" (pending) | "logo" | "lowres" | "cover" | "invalid"
  // chrome/Surface.qml hosts a tiny Canvas inside the PanelWindow (where
  // Canvas.available is true) and reports the dimensions and corner alphas here.
  property string browserArtKind: ""
  property string browserArtCheckedUrl: ""

  function reportBrowserArt(url, w, h, alphas) {
    if (!url || url !== rawArtUrl) return
    browserArtCheckedUrl = url
    browserArtKind = Players.classifyBrowserArt(w, h, alphas)
  }

  onRawArtUrlChanged: {
    browserArtKind = ""
    browserArtCheckedUrl = ""
  }

  Component.onCompleted: {
    if (present) {
      settledTitle = title
      settledArtist = artist
      settledAlbum = album
      announced = signature
    }
  }

  readonly property bool browserArtUsable: isBrowserArt
    && (browserArtKind === "cover" || browserArtKind === "lowres")
  readonly property bool hasDirectCover: rawArtUrl !== "" && !isBrowserArt
  readonly property bool hasUsableOwnCover: hasDirectCover || browserArtUsable
  readonly property bool needsLookup: present && !standing
    && (!hasUsableOwnCover && (!isBrowserArt || browserArtKind === "logo" || browserArtKind === "invalid"))
  readonly property bool wantsUpgrade: present && !standing && isBrowserArt && browserArtKind === "lowres"
    && settledArtist !== "" && settledTitle !== ""

  Artwork {
    id: artwork
    title: media.settledTitle
    artist: media.settledArtist
    album: media.settledAlbum
    mode: media.needsLookup ? "missing" : (media.wantsUpgrade ? "upgrade" : "")
  }

  // Ordered candidate URLs for Cover.qml: best quality first, automatic
  // fallback to original URL or browser thumbnail if an upgraded/remote URL
  // fails, and finally the playing app's own icon if no artwork exists at all.
  readonly property var coverSources: {
    if (fake) return fake.art ? [String(fake.art)] : []
    if (!present || standing) return []
    var list = []
    function push(u) {
      var s = String(u || "")
      if (s !== "" && list.indexOf(s) === -1) list.push(s)
    }
    if (hasDirectCover) {
      push(Players.sharpCover(rawArtUrl))
      push(rawArtUrl)
    } else if (browserArtUsable) {
      // Upgraded studio cover first when strict lookup matched; instant real
      // browser thumbnail immediately underneath (and shown while lookup runs).
      if (artwork.url !== "") push(artwork.url)
      push(rawArtUrl)
    } else if (artwork.url !== "") {
      push(artwork.url)
    }
    if (list.length === 0 && appIcon !== "") push(appIcon)
    return list
  }

  // Primary artwork URL (for ColorQuantizer and single-source callers).
  // Never hands an icon:// URL to ColorQuantizer when only appIcon is present.
  readonly property string cover: {
    if (fake) return String(fake.art || "")
    if (!present || standing) return ""
    if (hasDirectCover) return Players.sharpCover(rawArtUrl)
    if (browserArtUsable) return artwork.url !== "" ? artwork.url : rawArtUrl
    return artwork.url
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

  // ---- the app behind it: bring its window to the front (Spotify, the
  // browser window with the video, ...). When no window can be found (an
  // app hidden to the tray), ask the player itself to show it.
  readonly property bool canShow: present && !standing && !!player

  function showWindow() {
    if (!canShow || finder.running) return
    finder.asked = player
    finder.command = Scripts.showPlayerWindow(player.dbusName, title, player.desktopEntry, player.identity)
    finder.running = true
  }

  Process {
    id: finder
    property var asked: null
    onExited: function(code) {
      if (code !== 0 && asked && asked.canRaise) asked.raise()
      asked = null
    }
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

  // ---- track changes: a short now-playing card. Players send title,
  // artist and album as separate updates, so it waits for them to settle.
  readonly property string signature: title + "\u0001" + artist
  property string announced: ""
  // The track metadata once settled, for the artwork lookup.
  property string settledTitle: ""
  property string settledArtist: ""
  property string settledAlbum: ""
  onSignatureChanged: settleTimer.restart()
  onAlbumChanged: if (present) settleTimer.restart()

  // A demo swaps the track without it being news.
  function quietly() { Qt.callLater(function() { media.announced = media.signature }) }

  Timer {
    id: settleTimer
    interval: 450
    onTriggered: {
      media.settledTitle = media.title
      media.settledArtist = media.artist
      media.settledAlbum = media.album
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
