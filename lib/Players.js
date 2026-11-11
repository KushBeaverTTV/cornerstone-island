.pragma library

// Choosing which MPRIS player the island follows, and making the most of the
// artwork players hand over.

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
// directory named after the browser. When the page offers no artwork that
// file is just the browser logo, so it never counts as a cover.
var BROWSER_TEMP_ART = ["/.org.chromium.", "/.com.google.Chrome.", "/.com.brave.", "/.com.microsoft.Edge."]

function hasCover(url) {
  var u = String(url || "")
  if (u === "") return false
  for (var i = 0; i < BROWSER_TEMP_ART.length; i++)
    if (u.indexOf(BROWSER_TEMP_ART[i]) !== -1) return false
  return true
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

// Many players hand MPRIS the smallest size of a cover, which turns to mush
// when the island shows it large. These CDNs serve the same picture bigger
// at a predictable address; anything else passes through unchanged.
var COVER_UPGRADES = [
  // Spotify: the size code after the prefix (4851 = 64 px, 1e02 = 300 px).
  [/(i\.scdn\.co\/image\/ab6761(?:6d|61)0000)(?:4851|1e02|82c1)/, function(m, head) { return head + "b273" }],
  // SoundCloud: "-large" is 100 px.
  [/(sndcdn\.com\/artworks-[A-Za-z0-9\-]+?)-(?:large|small|tiny|badge)\.(jpg|png)/,
   function(m, head, ext) { return head + "-t500x500." + ext }],
  // YouTube thumbnails: default and mq are tiny, hq always exists.
  [/(i\.ytimg\.com\/vi\/[^\/]+\/)(?:default|mqdefault)\.jpg/, function(m, head) { return head + "hqdefault.jpg" }],
  // Deezer: the pixel size is part of the path.
  [/(dzcdn\.net\/images\/cover\/[0-9a-f]+\/)(?:250x250|400x400)-/, function(m, head) { return head + "500x500-" }],
  // Apple Music: a WxHbb segment names the size.
  [/(mzstatic\.com\/.*\/)\d+x\d+bb\.(jpg|png)/, function(m, head, ext) { return head + "600x600bb." + ext }]
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

// The first artwork in an iTunes search, raised from 100 to 600 px.
function posterFromItunes(body) {
  try {
    var results = JSON.parse(body).results || []
    for (var i = 0; i < results.length && i < 10; i++)
      if (results[i].artworkUrl100) return safeImage(String(results[i].artworkUrl100).replace(/100x100bb/, "600x600bb"))
  } catch (e) {}
  return ""
}
