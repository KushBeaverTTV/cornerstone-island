.pragma library

// Shell commands the island runs to fit into Omarchy. Each returns an argv
// for Quickshell.execDetached. Values always travel as positional arguments,
// never spliced into the script text.

// Helpers for the keybinding block in ~/.config/hypr/bindings.lua, which is
// written by Omarchy and the user as well, so it is edited carefully: only a
// regular file (not a symlink) is touched, and an edit is written next to it
// and renamed over it in one step.
var BINDINGS_HELPERS = [
  'editable() { [ -f "$1" ] && [ ! -L "$1" ]; }',
  'replace_with_stdin() {',
  '  t=$(mktemp "$1.island.XXXXXX") || return 1',
  '  if cat > "$t" && chmod --reference="$1" "$t" && mv -f "$t" "$1"; then return 0; fi',
  '  rm -f "$t"; return 1',
  '}',
  'our_block() { sed -n "/^-- BEGIN $2\\$/,/^-- END $2\\$/p" "$1"; }',
  'without_block() { sed "/^-- BEGIN $2\\$/,/^-- END $2\\$/d" "$1"; }',
  'drop_block() {',
  '  editable "$1" || return 0',
  '  grep -qxF -e "-- BEGIN $2" "$1" || return 0',
  '  without_block "$1" "$2" | replace_with_stdin "$1"',
  '}'
].join("\n")

// The block the island keeps in bindings.lua for its keybinding.
function bindLine(key) {
  return 'o.bind("' + key + '", "Toggle island reserved space", "omarchy-shell dynamic-island reserveSpace toggle")'
}

function keybindBlock(pluginId, key) {
  return [
    "-- BEGIN " + pluginId,
    "-- Added by the " + pluginId + " plugin and removed with it. Change the key",
    "-- with \"keybind\" in its entry in ~/.config/omarchy/shell.json.",
    bindLine(key),
    "-- END " + pluginId
  ].join("\n")
}

function removeKeybind(bindingsPath, pluginId) {
  return ["sh", "-c", BINDINGS_HELPERS + '\ndrop_block "$1" "$2"', "sh", bindingsPath, pluginId]
}

// Write the block, unless it is already there as it should be, or the key is
// taken by some other binding (then the block goes, and the key stays theirs).
// Hyprland lists the island's own binding too, so the clash check only runs
// when the island's line is not already in the file.
// `keybind` is the setting as written ("SUPER + ALT + I"); `parsed` is
// Config.parseKeybind of it ({ mask, key }), for the clash check.
function writeKeybind(bindingsPath, pluginId, keybind, parsed) {
  var script = BINDINGS_HELPERS + "\n" + [
    'editable "$1" || exit 0',
    '[ "$(our_block "$1" "$2")" = "$3" ] && exit 0',
    'if ! grep -qxF -e "$4" "$1" && hyprctl binds -j 2>/dev/null | jq -e --argjson m "$5" --arg k "$6" \\',
    "    'any(.[]; .modmask == $m and (.key | ascii_downcase) == ($k | ascii_downcase))' >/dev/null; then",
    '  drop_block "$1" "$2"; exit 0',
    'fi',
    "{ without_block \"$1\" \"$2\" | sed -e :a -e '/^\\n*$/{$d;N;ba' -e '}'; echo; printf '%s\\n' \"$3\"; } | replace_with_stdin \"$1\""
  ].join("\n")
  return ["sh", "-c", script, "sh", bindingsPath, pluginId, keybindBlock(pluginId, keybind), bindLine(keybind),
          String(parsed.mask), parsed.key]
}

// Take one of Omarchy's own services over: leave a marker saying the island
// did it, then disable Omarchy's plugin. `name` is both the plugin
// (omarchy.<name>) and the marker file (<name>-takeover).
function takeOver(stateDir, name) {
  return ["sh", "-c", 'mkdir -p "$1" && touch "$1/$2-takeover" && "$OMARCHY_PATH/bin/omarchy-plugin-disable" "omarchy.$2"',
          "sh", stateDir, name]
}

// Give one back, but only one the island took (its marker is there).
function giveBack(stateDir, name) {
  return ["sh", "-c", '[ -f "$1/$2-takeover" ] && "$OMARCHY_PATH/bin/omarchy-plugin-enable" "omarchy.$2" && rm -f "$1/$2-takeover"',
          "sh", stateDir, name]
}

// Run when the island object is destroyed. The shell destroys it on every
// reload and restart too, so nothing happens unless, a few seconds later,
// shell.json can be read and the island's entry is really gone from it (jq
// exit status 4: valid JSON, no match). An unreadable or half-written file
// is never taken as "removed": a wrong hand-back would start Omarchy's
// notification service next to the island's. Then everything the island
// took over goes back, with retries since the shell may be mid-reload, a
// marker is cleared once Omarchy's plugin is no longer disabled, and the
// keybinding block is removed.
function handBackIfRemoved(pluginId, stateDir, bindingsPath) {
  var script = BINDINGS_HELPERS + "\n" + [
    'sleep 4',
    'c="$HOME/.config/omarchy/shell.json"',
    'jq -e --arg id "$1" \'.plugins[]? | select(.id == $id)\' "$c" >/dev/null 2>&1',
    '[ $? -eq 4 ] || exit 0',
    'for t in notifications osd; do',
    '  [ -f "$2/$t-takeover" ] || continue',
    '  for try in 1 2 3; do "$OMARCHY_PATH/bin/omarchy-plugin-enable" "omarchy.$t" >/dev/null 2>&1 && break; sleep 2; done',
    '  sleep 1',
    '  jq -e --arg p "omarchy.$t" \'(.disabledPlugins // []) | index($p)\' "$c" >/dev/null 2>&1 || rm -f "$2/$t-takeover"',
    'done',
    'drop_block "$3" "$1"'
  ].join("\n")
  return ["sh", "-c", script, "sh", pluginId, stateDir, bindingsPath]
}
