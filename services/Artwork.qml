import QtQuick
import "../lib/Players.js" as Players

// Cover art lookup for players that send none (browser video like Prime Video
// or Netflix, players without embedded art) or send only a tiny browser
// thumbnail (like YouTube Music's 120 px temp PNG).
//
// Music tracks (with artist/album metadata) query iTunes Music then Deezer
// for crisp 500–600 px studio covers; in "upgrade" mode both artist and title
// must strictly match so a real low-res cover is never swapped for a wrong
// song. Video titles without an artist query TVmaze, iTunes TV, iTunes Movie,
// then iTunes Music as a final fallback.
//
// Requests go only to these fixed HTTPS services, carry nothing but the
// track/show terms, time out after 6 s, cap responses at 2 MiB, and accept
// only validated https:// image addresses.
Item {
  id: artwork

  // Track metadata to look up.
  property string title: ""
  property string artist: ""
  property string album: ""
  // "" (idle) | "missing" (no real cover) | "upgrade" (strict high-res upgrade)
  property string mode: ""

  readonly property bool isVideo: mode === "missing" && Players.hasVideoServicePrefix(title)
  readonly property bool isMusic: !isVideo && (artist !== "" || album !== "")
  readonly property string cleanTitle: Players.cleanTrackTitle(title)
  readonly property string videoTerm: Players.posterQuery(title)

  readonly property string cacheKey: {
    if (mode === "" || title === "") return ""
    if (mode === "upgrade" && (artist === "" || cleanTitle === "")) return ""
    return [mode, artist.toLowerCase(), cleanTitle.toLowerCase(), album.toLowerCase()].join("\u0001")
  }

  // The resolved https cover URL for the current key, once found.
  readonly property string url: cacheKey !== "" ? (found[cacheKey] || "") : ""

  property var found: ({})
  property var tried: ({})
  property var order: []

  readonly property int timeoutMs: 6000
  readonly property int maxBytes: 2 * 1024 * 1024
  readonly property int maxCache: 200

  onCacheKeyChanged: lookUp()

  Component {
    id: deadline
    Timer { interval: artwork.timeoutMs }
  }

  function sources() {
    var strict = mode === "upgrade"
    var t = cleanTitle || title
    var a = artist
    var al = album
    if (isMusic) {
      var q = encodeURIComponent((a ? a + " " : "") + t)
      return [
        {
          url: "https://itunes.apple.com/search?term=" + q + "&media=music&entity=song&limit=6",
          read: function(body) { return Players.coverFromItunes(body, t, a, al, strict) }
        },
        {
          url: "https://api.deezer.com/search?q=" + q + "&limit=6",
          read: function(body) { return Players.coverFromDeezer(body, t, a, al, strict) }
        }
      ]
    }
    if (strict) return []
    var vq = encodeURIComponent(videoTerm || t)
    var list = [
      { url: "https://api.tvmaze.com/search/shows?q=" + vq, read: Players.posterFromTvmaze },
      { url: "https://itunes.apple.com/search?term=" + vq + "&media=tvShow&limit=3", read: Players.posterFromItunes },
      { url: "https://itunes.apple.com/search?term=" + vq + "&media=movie&limit=3", read: Players.posterFromItunes }
    ]
    if (!isVideo && t !== "") {
      var mq = encodeURIComponent(t)
      list.push({
        url: "https://itunes.apple.com/search?term=" + mq + "&media=music&entity=song&limit=4",
        read: function(body) { return Players.coverFromItunes(body, t, "", "", false) }
      })
    }
    return list
  }

  function lookUp() {
    var key = cacheKey
    if (key === "" || tried[key]) return
    var list = sources()
    if (list.length === 0) return
    tried[key] = true
    order.push(key)
    if (order.length > maxCache) {
      var oldest = order.shift()
      delete tried[oldest]
      if (oldest in found) {
        var trimmed = Object.assign({}, found)
        delete trimmed[oldest]
        found = trimmed
      }
    }
    ask(key, list, 0)
  }

  function remember(key, image) {
    var f = Object.assign({}, found)
    f[key] = image
    found = f
  }

  function ask(key, list, index) {
    if (index >= list.length) return
    var source = list[index]
    var xhr = new XMLHttpRequest()
    var finished = false
    var giveUp = deadline.createObject(artwork)
    function next(image) {
      if (finished) return
      finished = true
      giveUp.destroy()
      if (image) remember(key, image)
      else ask(key, list, index + 1)
    }
    giveUp.triggered.connect(function() { xhr.abort(); next("") })
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      var body = xhr.status === 200 ? String(xhr.responseText || "") : ""
      next(body.length > 0 && body.length <= maxBytes ? source.read(body) : "")
    }
    xhr.open("GET", source.url)
    xhr.send()
    giveUp.start()
  }
}
