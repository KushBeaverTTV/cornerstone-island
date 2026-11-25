.pragma library

// Choosing which MPRIS player the island follows, matching it to its
// PipeWire playback stream(s), and making the most of the artwork players
// hand over.

// playerctld re-publishes whatever player is active; following it as well
// would show every song twice.
function isMirror(player) {
  var bus = String(player && player.dbusName || "").toLowerCase()
  var entry = String(player && player.desktopEntry || "").toLowerCase()
  return bus.indexOf("playerctld") !== -1 || entry === "playerctld"
}

function idOf(player) {
  return player ? String(player.dbusName || player.identity || "") : ""
}

function loaded(player) {
  return !!(player && (player.trackTitle || player.trackArtist))
}

// Chromium-family browsers write a temporary thumbnail for MPRIS under a dot
// file/directory named after the browser (e.g. /tmp/.com.google.Chrome.XXXX).
// Sometimes it is real MediaSession album art (YouTube Music, Spotify Web);
// when the page provides no art it is the browser's own transparent logo.
var BROWSER_TEMP_ART = [
  "/.org.chromium.",
  "/.com.google.Chrome.",
  "/.com.brave.",
  "/.com.microsoft.Edge.",
  "/.com.vivaldi.",
  "/.com.opera."
]

function isBrowserTempArt(url) {
  var u = String(url || "")
  if (u === "") return false
  for (var i = 0; i < BROWSER_TEMP_ART.length; i++)
    if (u.indexOf(BROWSER_TEMP_ART[i]) !== -1) return true
  return false
}

// Whether a URL is a non-browser-temp direct cover (used when comparing
// two MPRIS players showing the same song, e.g. Spotify desktop vs browser).
function hasCover(url) {
  var u = String(url || "")
  return u !== "" && !isBrowserTempArt(u)
}

// Classify a local browser temp image from its dimensions and the alpha
// values (0..255) of its four corners. Browser logos (Chrome, Chromium,
// Brave, Edge, Vivaldi, Opera) are square icons on transparent backgrounds
// (all 4 corners transparent); album covers and video stills are opaque.
// Returns "invalid" | "logo" | "lowres" | "cover".
function classifyBrowserArt(width, height, cornerAlphas) {
  var w = Number(width) || 0
  var h = Number(height) || 0
  if (w <= 0 || h <= 0) return "invalid"
  if (Array.isArray(cornerAlphas) && cornerAlphas.length >= 4 && w === h) {
    var allTransparent = true
    for (var i = 0; i < 4; i++) {
      if ((Number(cornerAlphas[i]) || 0) >= 16) { allTransparent = false; break }
    }
    if (allTransparent) return "logo"
  }
  return Math.max(w, h) <= 180 ? "lowres" : "cover"
}

// Chromium-family browsers expose MPRIS Volume as a read-only/no-op property,
// so per-source volume for them must come from their PipeWire playback stream.
function isBrowser(player) {
  var text = [
    player && player.dbusName,
    player && player.desktopEntry,
    player && player.identity
  ].join(" ").toLowerCase()
  return /chrom(e|ium)|brave|edge|vivaldi|opera/.test(text)
}

// How much a player tells about its track: a real cover counts most, then a
// separate artist. Breaks ties between two players showing the same song.
function detail(player) {
  return (hasCover(player.trackArtUrl) ? 2 : 0) + (player.trackArtist ? 1 : 0)
}

function titleKey(player) {
  return String(player && player.trackTitle || "").toLowerCase().replace(/\s+/g, " ").trim()
}

// Two players on one song, typically a music app and the browser tab that
// mirrors it ("Boyfriend" vs "Boyfriend • Karan Aujla, Ikky", same length).
function sameSong(a, b) {
  var ta = titleKey(a)
  var tb = titleKey(b)
  if (ta === "" || tb === "") return false
  if (ta.indexOf(tb) !== 0 && tb.indexOf(ta) !== 0) return false
  var bothTimed = a.lengthSupported && b.lengthSupported && a.length > 0 && b.length > 0
  return !bothTimed || Math.abs(a.length - b.length) < 2
}

// The players worth showing: real ones with something loaded, and of any two
// on the same song only the one that says more about it.
function eligible(players) {
  var kept = []
  for (var i = 0; i < players.length; i++) {
    var p = players[i]
    if (!p || isMirror(p) || !loaded(p)) continue
    var twin = -1
    for (var j = 0; j < kept.length && twin === -1; j++)
      if (sameSong(p, kept[j])) twin = j
    if (twin === -1) kept.push(p)
    else if (detail(p) > detail(kept[twin])) kept[twin] = p
  }
  return kept
}

function richest(list, accept) {
  var best = null
  for (var i = 0; i < list.length; i++)
    if (accept(list[i]) && (best === null || detail(list[i]) > detail(best))) best = list[i]
  return best
}

// The player to show. The island stays with the one it already follows
// (`followedId`) so a pause does not hand the island to a browser tab that
// keeps claiming to play; the caller switches when another player starts.
// Otherwise: the richest player that is playing, else the richest at all.
function choose(players, followedId) {
  var list = eligible(players)
  for (var i = 0; i < list.length; i++)
    if (followedId && idOf(list[i]) === followedId) return list[i]
  return richest(list, function(p) { return p.isPlaying }) || richest(list, function() { return true })
}

// ---- PipeWire playback stream matching (for per-source volume)

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

// Never reads node.properties so it is safe to run before PwObjectTracker binds.
function isPlaybackStream(node) {
  if (!node || !node.isStream) return false
  if (node.isSink === true) return true
  var mediaClass = String(node.type || "")
  return /Stream\/Output\/Audio|AudioOutStream|Output/.test(mediaClass)
}

function streamLabelKey(label) {
  return String(label || "").toLowerCase()
    .replace(/^pipewire alsa \[/, "")
    .replace(/^alsa playback \[/, "")
    .replace(/\]$/, "")
    .replace(/[^a-z0-9]+/g, "")
}

function isAnonymousStream(label) {
  var s = String(label || "").trim().toLowerCase()
  return s === "" || s === "audio-src" || s === "playback" || s === "audio stream" || s === "audiostream"
}

function streamRawLabel(node) {
  if (!node) return ""
  var p = nodeProps(node)
  return String(p["application.name"] || node.description || p["media.name"] || p["node.name"] || node.name || "").trim()
}

function streamKeys(node) {
  if (!node) return []
  var p = nodeProps(node)
  var raw = [p["application.name"], p["application.process.binary"], node.description, p["node.name"], node.name]
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var k = streamLabelKey(raw[i])
    if (k && !isAnonymousStream(raw[i]) && out.indexOf(k) === -1) out.push(k)
  }
  return out
}

function playerKeys(player) {
  if (!player) return []
  var dbus = String(player.dbusName || "")
    .replace(/^org\.mpris\.MediaPlayer2\./i, "")
    .replace(/\.instance\d+$/i, "")
  var raw = [player.desktopEntry, player.identity, dbus]
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var k = streamLabelKey(raw[i])
    if (k && out.indexOf(k) === -1) out.push(k)
  }
  // Chromium-based browsers may register on dbus as "chromium" while PipeWire
  // names the stream "Google Chrome" / "chrome" (or vice versa).
  if (out.indexOf("chromium") !== -1 && out.indexOf("chrome") === -1) out.push("chrome")
  return out
}

function keysOverlap(aList, bList) {
  for (var i = 0; i < aList.length; i++) {
    var a = aList[i]
    if (a.length < 2) continue
    for (var j = 0; j < bList.length; j++) {
      var b = bList[j]
      if (b.length < 2) continue
      if (a === b || a.indexOf(b) !== -1 || b.indexOf(a) !== -1) return true
    }
  }
  return false
}

// PipeWire playback streams belonging to `player`. Named matches come first;
// if none match directly, an anonymous stream ("audio-src", common with
// Chromium/CEF players like Spotify) matches when no other playing player is
// also missing a named stream.
function streamsForPlayer(player, streams, players) {
  if (!player || !Array.isArray(streams) || streams.length === 0) return []
  var pKeys = playerKeys(player)
  if (pKeys.length === 0) return []

  var direct = []
  var anonymous = []
  for (var i = 0; i < streams.length; i++) {
    var s = streams[i]
    if (!s || !s.audio) continue
    var sKeys = streamKeys(s)
    if (sKeys.length === 0 || isAnonymousStream(streamRawLabel(s))) {
      anonymous.push(s)
    } else if (keysOverlap(pKeys, sKeys)) {
      direct.push(s)
    }
  }
  if (direct.length > 0) return direct
  if (anonymous.length === 0) return []

  // Claim anonymous streams only if this player is the sole unclaimed active player.
  var all = Array.isArray(players) ? players : []
  var myId = idOf(player)
  for (var j = 0; j < all.length; j++) {
    var other = all[j]
    if (!other || isMirror(other) || idOf(other) === myId || !other.isPlaying) continue
    var oKeys = playerKeys(other)
    var hasNamed = false
    for (var k = 0; k < streams.length; k++) {
      if (keysOverlap(oKeys, streamKeys(streams[k]))) { hasNamed = true; break }
    }
    if (!hasNamed) return []
  }
  return anonymous
}

// App icon candidates for an MPRIS player (desktop entry, identity, dbus name,
// plus slugified forms and well-known browser aliases).
function playerIconCandidates(player) {
  if (!player) return []
  var dbus = String(player.dbusName || "")
    .replace(/^org\.mpris\.MediaPlayer2\./i, "")
    .replace(/\.instance\d+$/i, "")
  var raw = [player.desktopEntry, player.identity, dbus]
  var out = []
  function add(name) {
    var n = String(name || "").trim()
    if (n && out.indexOf(n) === -1) out.push(n)
    var slug = n.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^[-.]+|[-.]+$/g, "")
    if (slug && out.indexOf(slug) === -1) out.push(slug)
  }
  for (var i = 0; i < raw.length; i++) add(raw[i])
  var lower = raw.join(" ").toLowerCase()
  if (lower.indexOf("chrome") !== -1) add("google-chrome")
  if (lower.indexOf("brave") !== -1) add("brave-browser")
  if (lower.indexOf("firefox") !== -1) add("firefox")
  return out
}

// ---- Cover art upgrades and metadata lookup

// Many players hand MPRIS the smallest size of a cover, which turns to mush
// when the island shows it large. These CDNs serve the same picture bigger
// at a predictable address; anything else passes through unchanged.
var COVER_UPGRADES = [
  // Spotify: the size code after the prefix (4851 = 64 px, 1e02 = 300 px).
  [/(i\.scdn\.co\/image\/ab6761(?:6d|61|67)0000)(?:4851|1e02|82c1)/, function(m, head) { return head + "b273" }],
  // SoundCloud: "-large" is 100 px.
  [/(sndcdn\.com\/artworks-[A-Za-z0-9\-]+?)-(?:large|small|tiny|badge)\.(jpg|png)/,
   function(m, head, ext) { return head + "-t500x500." + ext }],
  // YouTube thumbnails: default and mq are tiny, hq always exists.
  [/(i\.ytimg\.com\/vi\/[^\/]+\/)(?:default|mqdefault)\.jpg/, function(m, head) { return head + "hqdefault.jpg" }],
  // YouTube Music / Google CDN: upgrade small square thumbnails to 544 px.
  [/(lh3\.googleusercontent\.com\/[^=?]+)=w\d+-h\d+/, function(m, head) { return head + "=w544-h544" }],
  [/(lh3\.googleusercontent\.com\/[^=?]+)=s\d+/, function(m, head) { return head + "=s544" }],
  // Deezer: the pixel size is part of the path.
  [/(dzcdn\.net\/images\/cover\/[0-9a-f]+\/)(?:56x56|120x120|250x250|400x400)-/, function(m, head) { return head + "500x500-" }],
  // Apple Music: a WxHbb segment names the size.
  [/(mzstatic\.com\/.*\/)\d+x\d+bb\.(jpg|png)/, function(m, head, ext) { return head + "600x600bb." + ext }],
  // Tidal: WxH.jpg in the path.
  [/(resources\.tidal\.com\/images\/.*\/)\d+x\d+\.jpg/, function(m, head) { return head + "640x640.jpg" }],
  // Bandcamp: _2/_7/_8/_9 are small thumbnails, _10 is 1200 px.
  [/(f4\.bcbits\.com\/img\/a\d+)_(?:2|3|4|5|7|8|9|14|16)\.(jpg|png)/, function(m, head, ext) { return head + "_10." + ext }]
]

function sharpCover(url) {
  var u = String(url || "")
  for (var i = 0; i < COVER_UPGRADES.length; i++)
    u = u.replace(COVER_UPGRADES[i][0], COVER_UPGRADES[i][1])
  return u
}

// The show or film a video title is about, for looking its poster up:
// "Prime Video: Star Trek: Picard - Season 3" -> "Star Trek: Picard".
var SERVICES = ["Prime Video", "Netflix", "Hulu", "Disney+", "Paramount+", "Apple TV+", "YouTube", "Max", "Peacock"]
var EPISODE_TAILS = [/\s+-\s+Season\s+\d+.*$/i, /\s+Season\s+\d+.*$/i, /\s+-\s+S\d{1,2}E\d{1,3}.*$/i, /\s+-\s+Episode\s+\d+.*$/i]

function hasVideoServicePrefix(title) {
  var t = String(title || "").trim()
  for (var i = 0; i < SERVICES.length; i++)
    if (t.indexOf(SERVICES[i] + ": ") === 0) return true
  return false
}

function posterQuery(title) {
  var t = String(title || "").replace(/\s+/g, " ").trim()
  for (var i = 0; i < SERVICES.length; i++) {
    if (t.indexOf(SERVICES[i] + ": ") === 0) { t = t.slice(SERVICES[i].length + 2); break }
  }
  t = t.split(" | ")[0]
  if (t.indexOf("Watch ") === 0) t = t.slice(6)
  for (var j = 0; j < EPISODE_TAILS.length; j++) t = t.replace(EPISODE_TAILS[j], "")
  return t.trim()
}

// Clean a song title for search: drop "(Official Video)", "[Lyrics]", etc.
function cleanTrackTitle(title) {
  return String(title || "")
    .replace(/\s*[\(\[]\s*(?:official\s+(?:music\s+)?(?:video|audio|lyric\s+video|visualizer)|lyrics?|audio|hd|4k|hq|mv|explicit)\s*[\)\]]/gi, "")
    .replace(/\s+/g, " ")
    .trim()
}

function normText(s) {
  return String(s || "").toLowerCase()
    .replace(/[\(\[\{][^\)\]\}]*[\)\]\}]/g, " ")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
}

function textMatches(wanted, candidate) {
  var w = normText(wanted)
  var c = normText(candidate)
  if (!w || !c) return false
  if (w === c || c.indexOf(w) !== -1 || w.indexOf(c) !== -1) return true
  // First token match when artist string lists multiple artists ("Sally Sossa, Lil Durk").
  var wFirst = w.split(" ")[0]
  var cFirst = c.split(" ")[0]
  return wFirst.length >= 3 && wFirst === cFirst && (w.split(" ").length > 1 || c.split(" ").length > 1)
}

function scoreMusicHit(hitTitle, hitArtist, hitAlbum, wantedTitle, wantedArtist, wantedAlbum) {
  var score = 0
  var wt = normText(wantedTitle), ht = normText(hitTitle)
  var wa = normText(wantedArtist), ha = normText(hitArtist)
  var wal = normText(wantedAlbum), hal = normText(hitAlbum)
  var titleOk = wt !== "" && ht !== "" && (wt === ht || ht.indexOf(wt) !== -1 || wt.indexOf(ht) !== -1)
  var artistOk = wa !== "" && ha !== "" && textMatches(wantedArtist, hitArtist)
  if (wt && ht && wt === ht) score += 4
  else if (titleOk) score += 2
  if (wa && ha && wa === ha) score += 4
  else if (artistOk) score += 2
  if (wal && hal && (wal === hal || hal.indexOf(wal) !== -1 || wal.indexOf(hal) !== -1)) score += 3
  return { score: score, titleOk: titleOk, artistOk: artistOk }
}

// Only ever an https image address from a source the island asked; anything
// else from a response is ignored.
function safeImage(url) {
  var u = String(url || "")
  return /^https:\/\/[^\s"'<>]+$/.test(u) && u.length < 1024 ? u : ""
}

// The first poster in a TVmaze show search, full size.
function posterFromTvmaze(body) {
  try {
    var hits = JSON.parse(body)
    for (var i = 0; i < hits.length && i < 10; i++) {
      var image = hits[i] && hits[i].show && hits[i].show.image
      if (image) return safeImage(image.original || image.medium)
    }
  } catch (e) {}
  return ""
}

// The first artwork in an iTunes TV/movie search, raised from 100 to 600 px.
function posterFromItunes(body) {
  try {
    var results = JSON.parse(body).results || []
    for (var i = 0; i < results.length && i < 10; i++)
      if (results[i].artworkUrl100) return safeImage(String(results[i].artworkUrl100).replace(/100x100bb/, "600x600bb"))
  } catch (e) {}
  return ""
}

// Best matching music cover from an iTunes song search, upgraded to 600 px.
// With `strict`, both title and artist must match (used when upgrading a
// real low-res browser thumbnail so we never swap in the wrong cover).
function coverFromItunes(body, title, artist, album, strict) {
  try {
    var results = JSON.parse(body).results || []
    var bestUrl = ""
    var bestScore = -1
    for (var i = 0; i < results.length && i < 10; i++) {
      var r = results[i]
      if (!r || !r.artworkUrl100) continue
      var url = safeImage(String(r.artworkUrl100).replace(/100x100bb/, "600x600bb"))
      if (!url) continue
      var m = scoreMusicHit(r.trackName, r.artistName, r.collectionName, title, artist, album)
      if (strict && !(m.titleOk && m.artistOk)) continue
      if (!strict && artist && !m.artistOk && !m.titleOk) continue
      if (m.score > bestScore) { bestScore = m.score; bestUrl = url }
    }
    return bestUrl
  } catch (e) {}
  return ""
}

// Best matching music cover from a Deezer search (500–1000 px).
function coverFromDeezer(body, title, artist, album, strict) {
  try {
    var results = JSON.parse(body).data || []
    var bestUrl = ""
    var bestScore = -1
    for (var i = 0; i < results.length && i < 10; i++) {
      var r = results[i]
      var raw = r && r.album && (r.album.cover_big || r.album.cover_xl || r.album.cover_medium)
      var url = safeImage(raw)
      if (!url) continue
      var m = scoreMusicHit(r.title, r.artist && r.artist.name, r.album && r.album.title, title, artist, album)
      if (strict && !(m.titleOk && m.artistOk)) continue
      if (!strict && artist && !m.artistOk && !m.titleOk) continue
      if (m.score > bestScore) { bestScore = m.score; bestUrl = url }
    }
    return bestUrl
  } catch (e) {}
  return ""
}
