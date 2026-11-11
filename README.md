# Cornerstone Island

A Dynamic-Island style pill at the top of the screen, part of the Cornerstone
desktop by Kush Beaver Productionz.

It shows music (cover art, the song, an equaliser, and a full player with
seek, previous and next, and a "Play on" output picker), screen recording,
the microphone or camera in use, a timer and a stopwatch, the next meeting
and a month calendar, Bluetooth devices coming and going, volume and
brightness, charging and low battery, notifications with an inbox, short
messages (toasts) and live activities from scripts. Two live things at once
split into the pill and a bubble beside it.

While enabled it takes over Omarchy's notifications and on-screen display
(volume, brightness, microphone and similar popups) and hands them back when
it is removed.

Cornerstone parts:

- Cornerstone dictation: "Listening" with a running time (the ✕ in the
  opened island stops listening), "Transcribing", then "Typed N words",
  "Nothing heard" or "Dictation failed". Cornerstone's own recorder never
  shows as a generic microphone.
- Cover art at the best size the music service offers, and posters for
  browser video that sends no artwork (looked up by title on TVmaze and
  iTunes).

## Scripting

```
omarchy-shell dynamic-island toast "Build finished" "0 errors" "󰄬" green
omarchy-shell dynamic-island activity build '{"title":"Building","progress":0.4}'
omarchy-shell dynamic-island endActivity build "Done"
omarchy-shell dynamic-island timer 25m "Focus"
omarchy-shell dynamic-island stopwatch start|pause|toggle|reset
omarchy-shell dynamic-island calendar
omarchy-shell dynamic-island expand|collapse|toggle
omarchy-shell dynamic-island reserveSpace on|off|toggle
omarchy-shell dynamic-island state
omarchy-shell dynamic-island demo <kind>     # every state on demand; "demo off" ends it
```

SUPER + ALT + I toggles the space kept free for the island. The plugin writes
that binding into `~/.config/hypr/bindings.lua` itself (a key already taken
is left alone) and removes it when the plugin is removed.

## Settings

Every setting lives in the island's entry in `~/.config/omarchy/shell.json`
and is filled in with its default on first run: `style` (notch or island),
`background` (theme or black), `idle` (pill or hidden), `idleFace` (ticker,
clock, lens, none), `scale`, `topMargin`, `reserveSpace`, `keybind`,
`monitor` (a name, primary or focused), `layer` (top or overlay),
`expandOnHover`, `clockFormat`, `mediaLingerSeconds`, `notchWidth`,
`notchHeight`, `notchRadius`, `visualizerColor` (accent or artwork),
`textFont`, `glow`, `calendars`, `calendarLeadMinutes`, `holidays`,
`timerSound`, and on/off switches for `bluetooth`, `camera`, `calendar`,
`notifications`, `inbox`, `osd`, `volume`, `brightness`, `charging`,
`trackChange`, `recording` and `mic`.

Calendars added from the calendar view are kept in
`~/.config/omarchy/dynamic-island/calendars.json`.

## Layout of the code

- `Island.qml` wires everything together.
- `core/` settings, look (theme colours and sizes), the HUD queue, the stage
  (what shows and how big), Omarchy integration, IPC and demos.
- `services/` live sources: music, sound, power, backlight, recording,
  microphone and camera, notifications, timer and stopwatch, calendar,
  Bluetooth, script activities, Cornerstone dictation, the idle glance.
- `views/` one file per thing the island shows; `ui/` the parts they share;
  `chrome/` the window, the island's body, its status light and the bubble.
- `lib/` plain JavaScript (layout, formatting, the calendar reader, player
  choice, settings, shell scripts), covered by `tests/`.

Run the tests with:

```
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
```

The idea of an Omarchy dynamic island comes from omarchy-dynamic-island by
Arjun010011 (MIT, see LICENSE). This version is Cornerstone's own code.
