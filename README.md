# Cornerstone Island

A Dynamic-Island style pill at the top of the screen, part of the Cornerstone
desktop by Kush Beaver Productionz.

Shows music (cover art, scrolling title, visualizer, full player), screen
recording, mic and camera use, timers and a stopwatch, the next meeting,
Bluetooth devices, volume and brightness, charging, notifications with an
inbox, and live activities from scripts. It takes over Omarchy's
notifications and OSD while enabled and hands them back when removed.

Cornerstone additions: live Cornerstone dictation (Listening with a running
time and a stop button, Transcribing, then "Typed N words"), high-resolution
cover art, and artwork for browser video.

Scripting: `omarchy-shell dynamic-island toast|activity|endActivity|timer|...`
Keybinding: SUPER + ALT + I toggles reserved space (written to
~/.config/hypr/bindings.lua by the plugin itself).

Built from omarchy-dynamic-island by Arjun010011 (MIT, see LICENSE).
