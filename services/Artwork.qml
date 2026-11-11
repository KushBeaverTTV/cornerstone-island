import QtQuick
import "../lib/Players.js" as Players

// Cover art for players that send none. Browser video (Prime Video in Brave,
// for one) hands MPRIS a title and nothing else, so the island looks the
// show or film up by name: TVmaze first, then the iTunes catalog for shows,
// then films. Each title is looked up once per session; a miss is
// remembered too, so a strange title costs one round of requests.
//
// Requests go only to these fixed HTTPS services, carry nothing but the
// title, give up after a few seconds, and only an https image address is
// ever taken from an answer.
Item {
  id: artwork

  // What to look up ("" for nothing).
  property string query: ""
  // The poster for `query`, once found.
  readonly property string url: found[query] || ""

  property var found: ({})
  property var tried: ({})

  readonly property int timeoutMs: 6000
  readonly property int maxBytes: 2 * 1024 * 1024

  onQueryChanged: lookUp()

  Component {
    id: deadline
    Timer { interval: artwork.timeoutMs }
  }

  function sources(term) {
    var q = encodeURIComponent(term)
    return [
      { url: "https://api.tvmaze.com/search/shows?q=" + q, read: Players.posterFromTvmaze },
      { url: "https://itunes.apple.com/search?term=" + q + "&media=tvShow&limit=3", read: Players.posterFromItunes },
      { url: "https://itunes.apple.com/search?term=" + q + "&media=movie&limit=3", read: Players.posterFromItunes }
    ]
  }

  function lookUp() {
    var term = query
    if (term === "" || tried[term]) return
    tried[term] = true
    ask(term, sources(term), 0)
  }

  function remember(term, image) {
    var f = Object.assign({}, found)
    f[term] = image
    found = f
  }

  function ask(term, list, index) {
    if (index >= list.length) return
    var source = list[index]
    var xhr = new XMLHttpRequest()
    var finished = false
    var giveUp = deadline.createObject(artwork)
    function next(image) {
      if (finished) return
      finished = true
      giveUp.destroy()
      if (image) remember(term, image)
      else ask(term, list, index + 1)
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
