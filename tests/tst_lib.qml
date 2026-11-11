import QtQuick
import QtTest
import "../lib/Format.js" as Format
import "../lib/Layout.js" as Layout
import "../lib/Ics.js" as Ics
import "../lib/Players.js" as Players
import "../lib/Config.js" as Config
import "../lib/Notices.js" as Notices
import "../lib/Glyphs.js" as Glyphs
import "../lib/Scripts.js" as Scripts

TestCase {
  name: "Lib"

  // ---------------------------------------------------------------- Format
  function test_clock() {
    compare(Format.clock(272), "4:32")
    compare(Format.clock(4000), "1:06:40")
    compare(Format.clock(272.45, true), "4:32.4")
    compare(Format.clock(-5), "0:00")
  }

  function test_durations() {
    compare(Format.parseDuration("25"), 1500)
    compare(Format.parseDuration("25m"), 1500)
    compare(Format.parseDuration("90s"), 90)
    compare(Format.parseDuration("1h30m"), 5400)
    compare(Format.parseDuration("1h 30m"), 5400)
    compare(Format.parseDuration("1.5h"), 5400)
    compare(Format.parseDuration("2 hours and 5 minutes"), 7500)
    compare(Format.parseDuration("1:30"), 90)
    compare(Format.parseDuration("1:30:00"), 5400)
    compare(Format.parseDuration(""), 0)
    compare(Format.parseDuration("tea"), 0)
    compare(Format.parseDuration("25 mangos"), 0)
  }

  function test_until_and_ago() {
    compare(Format.until(1000 + 20000, 1000), "now")
    compare(Format.until(12 * 60000, 0), "in 12m")
    compare(Format.until(65 * 60000, 0), "in 1h 5m")
    compare(Format.until(120 * 60000, 0), "in 2h")
    compare(Format.ago(0, 30000), "now")
    compare(Format.ago(0, 5 * 60000), "5m")
    compare(Format.ago(0, 3 * 86400000), "3d")
  }

  // Text from other programs never keeps markup.
  function test_plain_strips_markup() {
    compare(Format.plain('<img src="https://example.invalid/tracker">Hi <b>there</b>'), "Hi there")
    compare(Format.plain("a<br/>b &amp; c &lt;d&gt;"), "a b & c <d>")
    compare(Format.plain("&amp;lt;b&amp;gt;"), "&lt;b&gt;")
    compare(Format.plain(null), "")
  }

  function test_clip_and_words() {
    compare(Format.clip("abcdef", 4), "abc…")
    compare(Format.clip("abc", 4), "abc")
    compare(Format.wordCount("  hello  big world "), 3)
    compare(Format.wordCount(""), 0)
  }

  // ---------------------------------------------------------------- Layout
  function stateWith(extra) {
    var s = { open: false, panel: "", focus: "", live: [], hasMedia: false, hud: null, banner: false,
              bannerActions: false, idleHidden: false, hovered: false }
    for (var k in extra) s[k] = extra[k]
    return s
  }

  function test_rank() {
    compare(Layout.rankLive({ media: true, recording: true, inbox: true }), ["recording", "media", "inbox"])
    compare(Layout.rankLive({ media: true, dictation: true }), ["dictation", "media"])
  }

  function test_choose_view() {
    compare(Layout.chooseView(stateWith({})), "idle")
    compare(Layout.chooseView(stateWith({ hovered: true })), "idle-hover")
    compare(Layout.chooseView(stateWith({ idleHidden: true })), "hidden")
    compare(Layout.chooseView(stateWith({ live: ["media"], hasMedia: true })), "media")
    compare(Layout.chooseView(stateWith({ live: ["media"], banner: true })), "notification")
    compare(Layout.chooseView(stateWith({ banner: true, bannerActions: true })), "notification-actions")
    // A level shows even over a banner; other HUDs wait behind it.
    compare(Layout.chooseView(stateWith({ banner: true, hud: { layout: "progress" } })), "hud-progress")
    compare(Layout.chooseView(stateWith({ banner: true, hud: { layout: "toast" } })), "notification")
    compare(Layout.chooseView(stateWith({ hud: { layout: "toast" } })), "hud-toast")
    compare(Layout.chooseView(stateWith({ hud: { layout: "label" } })), "hud-label")
  }

  function test_opened_views() {
    compare(Layout.chooseView(stateWith({ open: true })), "idle-expanded")
    compare(Layout.chooseView(stateWith({ open: true, hasMedia: true, live: ["media"] })), "media-expanded")
    compare(Layout.chooseView(stateWith({ open: true, live: ["recording"] })), "recording-expanded")
    compare(Layout.chooseView(stateWith({ open: true, live: ["recording", "media"], hasMedia: true })), "recording-media-expanded")
    compare(Layout.chooseView(stateWith({ open: true, live: ["dictation"] })), "dictation-expanded")
    compare(Layout.chooseView(stateWith({ open: true, live: ["timer", "media"], hasMedia: true, focus: "media" })), "media-expanded")
    compare(Layout.chooseView(stateWith({ open: true, live: ["stopwatch"] })), "clock-expanded")
    compare(Layout.chooseView(stateWith({ open: true, panel: "inbox", live: ["recording"] })), "inbox-expanded")
    compare(Layout.chooseView(stateWith({ open: true, panel: "outputs" })), "outputs-expanded")
    // An opened island ignores HUDs and banners.
    compare(Layout.chooseView(stateWith({ open: true, hud: { layout: "progress" }, banner: true })), "idle-expanded")
  }

  function test_shapes() {
    var none = { w: 0, h: 0, r: 0 }
    compare(Layout.shape("media", {}, none), { w: 300, h: 32, r: 16 })
    compare(Layout.shape("inbox-expanded", { inbox: 0 }, none).h, 72)
    compare(Layout.shape("inbox-expanded", { inbox: 9 }, none).h, Layout.shape("inbox-expanded", { inbox: 4 }, none).h)
    var cutout = { w: 200, h: 38, r: 10 }
    compare(Layout.shape("idle", {}, cutout), { w: 200, h: 38, r: 10 })
    compare(Layout.shape("media", {}, cutout), { w: 320, h: 38, r: 19 })
    // Opened views are not stretched around a cutout.
    compare(Layout.shape("media-expanded", {}, cutout).w, 404)
  }

  // ------------------------------------------------------------------- Ics
  function ics(lines) { return ["BEGIN:VCALENDAR"].concat(lines).concat(["END:VCALENDAR"]).join("\r\n") }
  function at(y, m, d, h, mi) { return new Date(y, m - 1, d, h || 0, mi || 0).getTime() }

  function test_ics_single_and_folded() {
    var events = Ics.read(ics(["BEGIN:VEVENT", "SUMMARY:Long ti", " tle", "DTSTART:20261112T090000",
                               "DTEND:20261112T093000", "LOCATION:Room https://meet.example/abc", "END:VEVENT"]))
    compare(events.length, 1)
    compare(events[0].title, "Long title")
    compare(events[0].url, "https://meet.example/abc")
    compare(Ics.between(events, at(2026, 11, 12), at(2026, 11, 13), false).length, 1)
  }

  function test_ics_weekly_with_exdate_and_count() {
    var events = Ics.read(ics(["BEGIN:VEVENT", "UID:s", "SUMMARY:Standup", "DTSTART:20261102T100000",
                               "DTEND:20261102T101500", "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6",
                               "EXDATE:20261104T100000", "END:VEVENT"]))
    var list = Ics.between(events, at(2026, 11, 1), at(2026, 12, 31), false)
    // Mon 2, (Wed 4 skipped), Mon 9, Wed 11, Mon 16, Wed 18: six counted, five shown.
    compare(list.length, 5)
    compare(new Date(list[1].start).getDate(), 9)
  }

  function test_ics_every_other_week() {
    var events = Ics.read(ics(["BEGIN:VEVENT", "SUMMARY:Sync", "DTSTART:20261104T100000",
                               "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE", "END:VEVENT"]))
    var days = Ics.between(events, at(2026, 11, 1), at(2026, 12, 10), false).map(function(o) { return new Date(o.start).getDate() })
    compare(days, [4, 18, 2])
  }

  function test_ics_monthly_by_weekday() {
    // Second Tuesday, and last Friday.
    var events = Ics.read(ics(["BEGIN:VEVENT", "SUMMARY:A", "DTSTART:20260113T090000", "RRULE:FREQ=MONTHLY;BYDAY=2TU", "END:VEVENT",
                               "BEGIN:VEVENT", "SUMMARY:B", "DTSTART:20260130T090000", "RRULE:FREQ=MONTHLY;BYDAY=-1FR", "END:VEVENT"]))
    var nov = Ics.between(events, at(2026, 11, 1), at(2026, 12, 1), false)
    compare(nov.length, 2)
    compare(new Date(nov[0].start).getDate(), 10)   // 2nd Tuesday of Nov 2026
    compare(new Date(nov[1].start).getDate(), 27)   // last Friday of Nov 2026
  }

  function test_ics_moved_occurrence_replaces_the_regular_one() {
    var events = Ics.read(ics([
      "BEGIN:VEVENT", "UID:x", "SUMMARY:1:1", "DTSTART:20261102T100000", "DTEND:20261102T103000",
      "RRULE:FREQ=WEEKLY", "END:VEVENT",
      "BEGIN:VEVENT", "UID:x", "SUMMARY:1:1 (moved)", "RECURRENCE-ID:20261109T100000",
      "DTSTART:20261110T150000", "DTEND:20261110T153000", "END:VEVENT",
      "BEGIN:VEVENT", "UID:x", "RECURRENCE-ID:20261116T100000", "DTSTART:20261116T100000", "STATUS:CANCELLED", "END:VEVENT"]))
    var list = Ics.between(events, at(2026, 11, 8), at(2026, 11, 22), false)
    compare(list.length, 1)
    compare(list[0].title, "1:1 (moved)")
  }

  function test_ics_all_day_and_by_day() {
    var events = Ics.read(ics(["BEGIN:VEVENT", "SUMMARY:Holiday", "DTSTART;VALUE=DATE:20261111", "END:VEVENT"]))
    compare(Ics.between(events, at(2026, 11, 11), at(2026, 11, 12), false).length, 0)
    var list = Ics.between(events, at(2026, 11, 11), at(2026, 11, 12), true)
    compare(list.length, 1)
    var map = Ics.byDay(list)
    verify(map[Ics.dayKey(at(2026, 11, 11))] !== undefined)
    verify(map[Ics.dayKey(at(2026, 11, 12))] === undefined)
  }

  function test_holidays() {
    compare(Ics.holiday("us").name, "United States")
    verify(Ics.holidayFeed("IN").indexOf("en.indian%23holiday") !== -1)
    compare(Ics.holidayFeed("XX"), "")
  }

  // --------------------------------------------------------------- Players
  function fakePlayer(fields) {
    var p = { dbusName: "", identity: "", desktopEntry: "", trackTitle: "", trackArtist: "", trackArtUrl: "",
              isPlaying: false, lengthSupported: true, length: 200 }
    for (var k in fields) p[k] = fields[k]
    return p
  }

  function test_player_choice() {
    var spotify = fakePlayer({ dbusName: "spotify", trackTitle: "Boyfriend", trackArtist: "Karan Aujla", trackArtUrl: "https://i.scdn.co/x" })
    var tab = fakePlayer({ dbusName: "chromium.1", trackTitle: "Boyfriend • Karan Aujla, Ikky", trackArtUrl: "file:///tmp/.org.chromium.Chromium.x", isPlaying: true })
    var proxy = fakePlayer({ dbusName: "org.mpris.MediaPlayer2.playerctld", trackTitle: "Boyfriend", isPlaying: true })
    compare(Players.eligible([spotify, tab, proxy]).length, 1)
    compare(Players.choose([tab, spotify, proxy], ""), spotify)
    var other = fakePlayer({ dbusName: "mpv", trackTitle: "Something else", isPlaying: true })
    compare(Players.choose([spotify, other], ""), other)
    compare(Players.choose([spotify, other], "spotify"), spotify)
  }

  function test_covers() {
    compare(Players.sharpCover("https://i.scdn.co/image/ab67616d00004851abcdef"), "https://i.scdn.co/image/ab67616d0000b273abcdef")
    compare(Players.sharpCover("https://i1.sndcdn.com/artworks-abc-def-large.jpg"), "https://i1.sndcdn.com/artworks-abc-def-t500x500.jpg")
    compare(Players.sharpCover("https://is1-ssl.mzstatic.com/image/thumb/a/b/100x100bb.jpg"), "https://is1-ssl.mzstatic.com/image/thumb/a/b/600x600bb.jpg")
    compare(Players.sharpCover("https://example.com/a.jpg"), "https://example.com/a.jpg")
    verify(!Players.hasCover("file:///tmp/.com.brave.Browser.x/thumb.png"))
    verify(Players.hasCover("https://example.com/a.jpg"))
  }

  function test_poster_query_and_parsing() {
    compare(Players.posterQuery("Prime Video: Star Trek: Picard - Season 3"), "Star Trek: Picard")
    compare(Players.posterQuery("Watch Severance | Apple TV+"), "Severance")
    compare(Players.posterFromTvmaze('[{"show":{"image":{"original":"https://static.tvmaze.com/a.jpg"}}}]'), "https://static.tvmaze.com/a.jpg")
    // Only https image addresses are taken from an answer.
    compare(Players.posterFromTvmaze('[{"show":{"image":{"original":"javascript:alert(1)"}}}]'), "")
    compare(Players.posterFromItunes('{"results":[{"artworkUrl100":"https://a/100x100bb.jpg"}]}'), "https://a/600x600bb.jpg")
    compare(Players.posterFromItunes("not json"), "")
  }

  // ---------------------------------------------------------------- Config
  function test_config() {
    compare(Config.parse("{"), null)
    compare(Config.parse("[]"), null)
    compare(Config.entryFor({ plugins: [{ id: "a" }, { id: "b", x: 1 }] }, "b").x, 1)
    compare(Config.missing({ style: "notch" }).indexOf("style"), -1)
    verify(Config.missing({}).indexOf("keybind") !== -1)
    compare(Config.parseKeybind("SUPER + ALT + I"), { mask: 72, key: "I" })
    compare(Config.parseKeybind("HYPER + I"), null)
    compare(Config.parseKeybind(""), null)
  }

  // --------------------------------------------------------------- Notices
  function test_notification_record_is_plain() {
    var r = Notices.record({ app: "Evil", summary: "<a href='x'>click</a>", body: "<img src=https://t.invalid/p>" }, 1, 5)
    compare(r.summary, "click")
    compare(r.body, "")
    compare(r.time, 5)
    compare(Notices.execArgv('["notify-send","hi"]'), ["notify-send", "hi"])
    compare(Notices.execArgv('["a", 1]'), null)
    compare(Notices.execArgv("rm -rf /"), null)
  }

  function test_banner_times() {
    compare(Notices.bannerMs({ critical: true }), 0)
    compare(Notices.bannerMs({ low: true, timeout: 0 }), 4000)
    compare(Notices.bannerMs({ timeout: 10000 }), 10000)
    compare(Notices.bannerMs({ timeout: 100000 }), 30000)
  }

  function test_osd_mapping() {
    var all = { volume: true, brightness: true }
    var level = Notices.osdHud({ icon: "brightness", value: "40", max: "100" }, all)
    compare(level.layout, "progress")
    compare(level.valueText, "40%")
    compare(Notices.osdHud({ icon: "volume", value: "40" }, { volume: false, brightness: true }), null)
    var mic = Notices.osdHud({ icon: "microphone-muted", message: "Microphone muted" }, all)
    compare(mic.layout, "label")
    compare(mic.icon, Glyphs.MIC_OFF)
    verify(mic.dim)
    compare(Notices.osdHud({ icon: "volume", message: "Headphones" }, all).valueText, "Playing on")
    compare(Notices.osdHud({}, all), null)
  }

  // ---------------------------------------------------------------- Scripts
  // Values travel as arguments; the clash check gets the bare key.
  function test_keybind_arguments() {
    var argv = Scripts.writeKeybind("/b.lua", "cornerstone.island", "SUPER + ALT + I", Config.parseKeybind("SUPER + ALT + I"))
    compare(argv.slice(4, 6), ["/b.lua", "cornerstone.island"])
    compare(argv[7], 'o.bind("SUPER + ALT + I", "Toggle island reserved space", "omarchy-shell dynamic-island reserveSpace toggle")')
    compare(argv.slice(8), ["72", "I"])
    verify(argv[6].indexOf("-- BEGIN cornerstone.island\n") === 0)
    verify(argv[2].indexOf("SUPER") === -1)
    var back = Scripts.handBackIfRemoved("cornerstone.island", "/state", "/b.lua")
    compare(back.slice(4), ["cornerstone.island", "/state", "/b.lua"])
    verify(back[2].indexOf("[ $? -eq 4 ] || exit 0") !== -1)
  }
}
