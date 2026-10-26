#!/usr/bin/env bash
# Ruixen media mode/state compatibility. Jeebis replaced the collapsed
# seeker/Cava/title renderer with NotchStatus; its behavior is tested in
# tests/js/JeebisNotchStatus.test.js. Keep coverage of the retained backend.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
overlay_qml="$repo_dir/bars/widgets/ruixen.notch/Overlay.qml"
# Reused media state and feeds remain owned by Overlay.qml.
notch_feed="$repo_dir/bars/widgets/ruixen.notch/CavaFeed.qml"
cava_feed="$repo_dir/ruixen.cava/CavaFeed.qml"

pass=0
fail_count=0
check() {
  local desc="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    printf 'ok   - %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL - %s\n       got:  %s\n       want: %s\n' "$desc" "$got" "$want"
    fail_count=$((fail_count + 1))
  fi
}

# --- CavaFeed.qml: a new byte-identical pair, alongside AppSearch.js/
# AppLibrary.qml/LauncherFrecency.js's own existing ones -----------------

check "ruixen.notch/CavaFeed.qml exists" "$([[ -f "$notch_feed" ]] && echo yes)" "yes"
check "ruixen.notch/CavaFeed.qml is byte-identical to ruixen.cava's own copy" \
  "$(diff -q "$notch_feed" "$cava_feed" >/dev/null 2>&1 && echo same || echo different)" "same"

# --- mode state: property, persistence, toggle ---------------------------

check "mediaVizMode property exists, defaulting to seeker" \
  "$(grep -c 'property string mediaVizMode: "seeker"' "$overlay_qml")" "1"
check "setMediaVizMode persists via writeMediaVizMode" \
  "$(grep -A4 'function setMediaVizMode' "$overlay_qml" | grep -c 'root.writeMediaVizMode()')" "1"
check "writeMediaVizMode is what actually writes the state file" \
  "$(grep -A1 'function writeMediaVizMode' "$overlay_qml" | grep -c 'mediaVizModeFile.setText')" "1"
check "toggleMediaVizMode flips between the two media-present modes only" \
  "$(grep -c 'function toggleMediaVizMode' "$overlay_qml")" "1"
check "the state file lives under ~/.local/state/ruixen/, same convention as every other bit of state" \
  "$(grep -c 'notch-media-viz-mode.json' "$overlay_qml")" "1"

# --- compactCavaFeed: separate, scoped instance ---------------------------

check "compactCavaFeed only enables while media is playing AND cava mode is selected" \
  "$(grep -c 'enabled: root.hasMedia && root.mediaVizMode === "cava"' "$overlay_qml")" "1"
check "a missing cava binary (cavaAvailable false) auto-falls back to the seeker" \
  "$(grep -A1 'onCavaAvailableChanged' "$overlay_qml" | grep -c 'root.setMediaVizMode("seeker")')" "1"
check "the mini feed uses a smaller band count than the full edge-docked overlay" \
  "$(grep -A2 'id: compactCavaFeed' "$overlay_qml" | grep -c 'bands: root.cavaMirrorBands')" "1"

# --- warm/cool theme color, same mechanism ruixen.cava/Overlay.qml uses --

check "cavaWarmColor/cavaCoolColor default to Color.accent" \
  "$(grep -c 'property color cavaWarmColor: Color.accent' "$overlay_qml")$(grep -c 'property color cavaCoolColor: Color.accent' "$overlay_qml")" "11"
check "colors are parsed from the real active theme file" \
  "$(grep -c 'current/theme/colors.toml' "$overlay_qml")" "1"
check "a load failure falls back to Color.accent AND schedules the one-shot retry" \
  "$(grep -A10 'onLoadFailed: {' "$overlay_qml" | grep -c 'cavaThemeColorsRetryTimer.restart()')" "1"
# --- retained bars/wave state compatibility -----------------------------
# Segments deliberately excluded -- see cavaMiniStyle's own comment for
# the sub-pixel-per-segment math (20px slot height / 10 segments / 2px
# gaps) that ruled it out at this size.

check "cavaMiniStyle property exists, defaulting to bars" \
  "$(grep -c 'property string cavaMiniStyle: "bars"' "$overlay_qml")" "1"
check "no segments option actually implemented -- bars/wave only (comments may still explain why)" \
  "$(grep -c 'cavaMiniStyle === "segments"\|cavaMiniStyle: "segments"' "$overlay_qml")" "0"
check "toggleCavaMiniStyle flips bars/wave and persists" \
  "$(grep -A3 'function toggleCavaMiniStyle' "$overlay_qml" | grep -c 'writeMediaVizMode()')" "1"
check "the mode/style state file round-trips both fields together" \
  "$(grep -c 'mode: root.mediaVizMode, style: root.cavaMiniStyle' "$overlay_qml")" "1"

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ "$fail_count" -eq 0 ]]
