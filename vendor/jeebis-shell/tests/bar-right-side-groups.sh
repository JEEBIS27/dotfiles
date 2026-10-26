#!/usr/bin/env bash
# Ruixen's optional system/pinned/tray grouping, with Jeebis date/load
# islands inserted into the right-hand anchor chain:
# tray -> load -> plugin pins (including Agent) -> system -> date -> clock.
# Empty optional groups must collapse; shared padding comes from ShellConfig.
# These are source-wiring checks; visible layout still needs a live shell.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
bar_qml="$repo_dir/bars/v2/ruixen.bar/Bar.qml"
barpanel_qml="$repo_dir/bars/v2/ruixen.bar/BarPanel.qml"

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

# --- id-membership lists ---------------------------------------------
# Grew from four to five (ruixen.peripherals), back to four. The active
# screen-recording state now lives on ruixen.quickactions instead of adding
# a dynamic-width capturestatus slot to this fixed system group.
curated_ids_line="$(grep -m1 'readonly property var curatedRightIds:' "$bar_qml")"
check "curatedRightIds is the exact, fixed SYSTEM list: system-update, power, quickactions, settingsbutton, launcherbutton" \
  "$curated_ids_line" '  readonly property var curatedRightIds: ["omarchy.system-update", "ruixen.power", "ruixen.quickactions", "ruixen.settingsbutton", "ruixen.launcherbutton"]'

check "there is no separate sideRightIds list anymore (pill 2's own filter is inline: not tray, not curatedRightIds)" \
  "$(grep -c 'sideRightIds' "$bar_qml" || true)" "0"

# --- pill existence -----------------------------------------------------
for pill_id in curatedPill pluginPinsPill trayPill clockPill; do
  check "pill '$pill_id' exists, exactly once" \
    "$(grep -c "id: $pill_id\$" "$barpanel_qml" || true)" "1"
done

# The old togglesPill/rightPill/stayawakePill/stayawakeGroupPill/
# thirdPartyPill names must be fully retired from actual code (comments
# referencing the OLD names for historical context are fine and
# expected, so this only checks id: declarations, not prose).
for old_id in togglesPill rightPill stayawakePill stayawakeGroupPill thirdPartyPill; do
  check "no leftover 'id: $old_id' declaration" \
    "$(grep -c "id: $old_id\$" "$barpanel_qml" || true)" "0"
done

# --- Jeebis anchor chain: tray -> load -> pluginPins -> curated -> date -> clock
#
# This exact order is what makes "third-party lands left of the coffee"
# true on screen and not just in shell.json's own array order.
check "curatedPill anchors off the date island" \
  "$(grep -A2 'id: curatedPill$' "$barpanel_qml" | grep -c 'anchors.right: datePill.left' || true)" "1"
check "pluginPinsPill anchors off curatedPill (sits just left of SYSTEM)" \
  "$(grep -A2 'id: pluginPinsPill$' "$barpanel_qml" | grep -c 'anchors.right: curatedPill.left' || true)" "1"
check "trayPill anchors off the optional load island" \
  "$(grep -A2 'id: trayPill$' "$barpanel_qml" | grep -c 'anchors.right: loadPill.left' || true)" "1"

# --- docked-mode rendering: rightShoulderWing/rightDockedBg seam -------
#
# Direct live report: a thin vertical seam visible in docked mode right
# where the curved shoulder wing meets the flat merged pill background
# -- two independently-antialiased shapes meeting at the exact same X
# coordinate can each erode their own edge by a sub-pixel amount,
# letting the wallpaper show through as a hairline. Only rightShoulderWing
# was confirmed broken and fixed (a 1px deliberate overlap into
# rightDockedBg's own territory) -- leftShoulderWing was checked live and
# looked clean, so it's deliberately left untouched here, not an
# oversight. trayPill stays the leftmost pill of this cluster through
# every reorg above, so rightDockedBg/rightShoulderWing's own x formulas
# (anchored to trayPill.x) are unaffected by any of them.
check "rightShoulderWing overlaps rightDockedBg by 1px, not flush against it" \
  "$(grep -m1 'x: rightDockedBg.x - size' "$barpanel_qml")" '        x: rightDockedBg.x - size + 1'

# --- each pill's own ModuleList filters on the right id list -----------
check "curatedContent filters on the exact curatedRightIds membership" \
  "$(grep -A6 'id: curatedContent$' "$barpanel_qml" | grep -c 'barWindow\.barRoot\.curatedRightIds\.indexOf' || true)" "1"
check "trayContent is tray ONLY (exact id match, not a catch-all)" \
  "$(grep -A5 'id: trayContent$' "$barpanel_qml" | grep -c 'barWindow\.barRoot\.entryId(e) === "ruixen.tray"' || true)" "1"
check "pluginPinsContent is the catch-all now: not tray, not in curatedRightIds" \
  "$(grep -A5 'id: pluginPinsContent$' "$barpanel_qml" | grep -c 'curatedRightIds\.indexOf(id) === -1' || true)" "1"
check "pluginPinsContent also excludes ruixen.pluginpins itself (rendered separately, see pluginPinsToggle)" \
  "$(grep -A5 'id: pluginPinsContent$' "$barpanel_qml" | grep -c 'id !== "ruixen.pluginpins"' || true)" "1"

# --- pluginpins toggle icon: fixed at this pill's own right edge -------
#
# Direct request: "can you make it right of the pill group, so its like
# thing that stays fix at the first right position of the pill group".
# A ModuleList's own render order otherwise just follows shell.json's
# array order, which drifts every time something is pinned/unpinned
# through ruixen.pluginpins itself -- pulling the toggle out into its
# own ModuleSlot, anchored directly to this pill's own right edge, is
# what makes its position a real structural guarantee instead of a
# data-order coincidence.
check "pluginPinsToggle (the toggle icon's own slot) exists, exactly once" \
  "$(grep -c 'id: pluginPinsToggle$' "$barpanel_qml" || true)" "1"
check "pluginPinsToggle anchors to this pill's own right edge" \
  "$(grep -A2 'id: pluginPinsToggle$' "$barpanel_qml" | grep -c 'anchors.right: parent.right' || true)" "1"
check "pluginPinsToggle reserves the same configured padding as other islands" \
  "$(grep -A12 'id: pluginPinsToggle$' "$barpanel_qml" | grep -c 'anchors.rightMargin: ShellConfig.islandPadding' || true)" "1"

# Direct live report after the toggle was first pulled into its own
# slot: "it doesnt shrink or expand anymore" and "the pill is lop
# sided now" -- both traced to the exact same stale-.implicitWidth bug
# curatedContent/trayContent already learned from (a ModuleList's own
# .implicitWidth, inherited from Loader, doesn't reliably update for a
# late-filled entries value; .width does -- see stayawakeGroupPill's
# own old comment, git history, for the original instance of this).
check "pluginPinsPill's own width reads pluginPinsContent.width, not .implicitWidth" \
  "$(grep -c 'width: pluginPinsContent\.width + pluginPinsToggle\.implicitWidth' "$barpanel_qml" || true)" "1"

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ "$fail_count" -eq 0 ]]
