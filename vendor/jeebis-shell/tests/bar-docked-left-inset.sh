#!/usr/bin/env bash
# Ruixen docked chrome retains its inset. Jeebis floating mode reads the
# editable screenSideGap instead of the old fixed 12px screen-edge margin.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
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

margin_line="$(grep -m1 'anchors.leftMargin: barWindow.barRoot.docked ? 20 : ShellConfig.screenSideGap' "$barpanel_qml" || true)"
check "menuPill's own leftMargin is mode-aware: 20 docked, configured screenSideGap floating" \
  "$margin_line" '        anchors.leftMargin: barWindow.barRoot.docked ? 20 : ShellConfig.screenSideGap'

# leftDockedBg's own outer bounds must stay anchored to the true screen
# edge (x: 0) regardless of this -- the fix is meant to be purely
# internal padding for the icon, not a shift of the merged background
# shape itself.
left_docked_bg_x="$(grep -A2 'id: leftDockedBg$' "$barpanel_qml" | grep -c 'x: 0$' || true)"
check "leftDockedBg's own x stays 0 (fix is internal padding only, not a background shift)" \
  "$left_docked_bg_x" "1"

check "sharp+docked no longer stretches leftDockedBg by itself; only fullbar style does" \
  "$(grep -m1 'width: barWindow.barRoot.dockedSkin.dockSpansFullWidth ? parent.width : (settingsPill.x + settingsPill.width)' "$barpanel_qml")" '        width: barWindow.barRoot.dockedSkin.dockSpansFullWidth ? parent.width : (settingsPill.x + settingsPill.width)'

check "sharp+docked keeps the normal docked left shoulder radius unless fullbar style is selected" \
  "$(grep -A40 'id: leftDockedBg$' "$barpanel_qml" | grep -m1 'bottomRightRadius: barWindow.barRoot.dockedSkin.dockSpansFullWidth ? 0 : barWindow.barRoot.shoulderWingSize')" '        bottomRightRadius: barWindow.barRoot.dockedSkin.dockSpansFullWidth ? 0 : barWindow.barRoot.shoulderWingSize'

check "rightDockedBg's legacy skin is hidden when the frame owns dock chrome" \
  "$(grep -A5 'id: rightDockedBg$' "$barpanel_qml" | grep -m1 'visible: barWindow.barRoot.docked && !barWindow.barRoot.dockedSkin.dockSpansFullWidth && !barWindow.barRoot.frameOwnsDockChrome')" '        visible: barWindow.barRoot.docked && !barWindow.barRoot.dockedSkin.dockSpansFullWidth && !barWindow.barRoot.frameOwnsDockChrome'

check "old sharp-only docked corner patch is behind fullbar style, not the lookfeel variant" \
  "$(grep -A5 'Historical sharp+docked full-strip corner patch' "$barpanel_qml" | grep -m1 'visible: barWindow.barRoot.docked && barWindow.barRoot.dockedSkin.dockSpansFullWidth')" '        visible: barWindow.barRoot.docked && barWindow.barRoot.dockedSkin.dockSpansFullWidth'

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ "$fail_count" -eq 0 ]]
