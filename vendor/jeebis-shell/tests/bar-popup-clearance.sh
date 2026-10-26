#!/usr/bin/env bash
# Jeebis popup reservation uses ShellConfig's actual notch/island dimensions.
# Preserve Ruixen's docked shoulder, seam and popup-hosting protections.
# Numerical variations are exercised in tests/js/JeebisShellAppearance.test.js.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
bar_qml="$repo_dir/bars/v2/ruixen.bar/Bar.qml"
barpanel_qml="$repo_dir/bars/v2/ruixen.bar/BarPanel.qml"
# Everything this file reads off the notch (margins.top, notchOuter's
# own restY/cornerSize/seamOverlap, the collapsed/expanded body size)
# is the window's own visible content -- lives in its own per-screen
# file now, see NotchWindow.qml's own header for why.
notch_overlay_qml="$repo_dir/bars/widgets/ruixen.notch/NotchWindow.qml"

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

check "floating bar size comes from the configured row height" \
  "$(grep -Fc 'readonly property int barSize: docked ? 34 : ShellConfig.barRowHeight(Style)' "$bar_qml")" "1"
check "bar and notch use the same collapsed bottom helper" \
  "$(grep -Fc 'readonly property int notchCollapsedBottomEdge: ShellConfig.collapsedBottom(Style)' "$bar_qml")$(grep -Fc 'height: panel.launcherOpen ? 190 : (panel.pinnedOpen ? 400 : ShellConfig.collapsedBottom(Style))' "$notch_overlay_qml")" "11"
check "bar horizontal reservation includes configured body width and both shoulders" \
  "$(grep -Fc 'readonly property int notchReservedWidth: ShellConfig.notchWidth + ShellConfig.radius * 2' "$bar_qml")" "1"
check "notch uses the configured body width" \
  "$(grep -Fc 'panel.pinnedOpen ? 900 : ShellConfig.notchWidth' "$notch_overlay_qml")" "1"
check "notch shoulders use the shared radius" \
  "$(grep -Fc 'readonly property int cornerSize: ShellConfig.radius' "$notch_overlay_qml")" "1"
check "notch attaches to the true screen edge" \
  "$(grep -Fc 'margins.top: 0' "$notch_overlay_qml")$(grep -Fc 'readonly property int restY: 0' "$notch_overlay_qml")" "11"

check "Overlay.qml's notchOuter has a small seamOverlap for fractional-scale mask joins" \
  "$(grep -c 'readonly property int seamOverlap: 2' "$notch_overlay_qml" || true)" "1"
check "Overlay.qml's centerMask overlaps both flanks to avoid hairline seams" \
  "$(( $(grep -A10 'id: centerMask' "$notch_overlay_qml" | grep -cF 'anchors.leftMargin: -notchOuter.seamOverlap' || true) + $(grep -A10 'id: centerMask' "$notch_overlay_qml" | grep -cF 'anchors.rightMargin: -notchOuter.seamOverlap' || true) ))" "2"
check "Overlay.qml's shadow center uses the same seam overlap as the mask" \
  "$(( $(grep -cF 'anchors.leftMargin: notchOuter.cornerSize - notchOuter.seamOverlap' "$notch_overlay_qml" || true) + $(grep -cF 'anchors.rightMargin: notchOuter.cornerSize - notchOuter.seamOverlap' "$notch_overlay_qml" || true) ))" "2"

# Docked and floating need different input heights. Docked owns the
# frame-hem/shoulder wing band below the row, so its Wayland surface must
# include that extra height. Floating only paints the pill row; keeping the
# docked wing band in floating creates a transparent input strip above the
# visible bar (issue #80: taps in that strip do nothing).
floating_visible_height_line="$(grep -m1 'readonly property int floatingVisibleBarHeight:' "$barpanel_qml")"
docked_visible_height_line="$(grep -m1 'readonly property int dockedVisibleBarHeight:' "$barpanel_qml")"
visible_bar_height_line="$(grep -m1 'readonly property int visibleBarHeight:' "$barpanel_qml")"
check "floating visibleBarHeight clears the notch without including dock-only shoulder wings" \
  "$floating_visible_height_line" "  readonly property int floatingVisibleBarHeight: Math.max(barWindow.barRoot.barSize, barWindow.barRoot.notchCollapsedBottomEdge)"
check "docked visibleBarHeight still includes shoulderWingSize for dock chrome" \
  "$docked_visible_height_line" "  readonly property int dockedVisibleBarHeight: Math.max(barWindow.barRoot.barSize + barWindow.barRoot.shoulderWingSize, barWindow.barRoot.notchCollapsedBottomEdge)"
check "visibleBarHeight branches by docked mode so floating does not get a dead input strip" \
  "$visible_bar_height_line" "  readonly property int visibleBarHeight: barWindow.barRoot.vertical ? barWindow.barRoot.barSize : (barWindow.barRoot.docked ? dockedVisibleBarHeight : floatingVisibleBarHeight)"

# implicitHeight must stay EITHER exactly visibleBarHeight OR
# visibleBarHeight + root.seamOverlap -- not some other, larger reach
# (still guarding against the "reach for center" regression this file's
# own header describes; a future edit growing this again some OTHER way
# needs to bring the input mask back with it, same as that reverted
# attempt needed). The "+ seamOverlap" branch is new, v2-era: BarPanel is
# a real small window again (not the fullscreen one v2 first tried), but
# its own top edge intentionally starts a few px higher than v1's ever
# did, painting a small insurance-overlap band into where the shell
# frame's own separate surface edge is (see BarPanel's own seamOverlap
# comment) -- implicitHeight grows by that same small, fixed amount so
# the window's real BOTTOM edge (and thus anchorWindow.height for every
# popup this whole file is about) lands exactly where v1's always did,
# regardless of the extra room claimed at the top.
implicit_height_line="$(grep -m1 'implicitHeight: barWindow.barRoot.vertical ? 0 : ' "$barpanel_qml")"
check "implicitHeight is visibleBarHeight, optionally + root.seamOverlap -- not some other, larger reach" \
  "$implicit_height_line" "  implicitHeight: barWindow.barRoot.vertical ? 0 : visibleBarHeight + barWindow.barRoot.seamOverlap"

# The docked/floating split top margin (reverted from #29's own attempt
# to unify it) is unrelated to this fix and must stay untouched by it.
# frameInset/topInset/screenMarginTop moved from BarPanel onto root
# itself (a later fix, see below) so widgets could read the bar's own
# current screen offset -- still exactly one definition each.
check "root.frameInset (docked's own top margin) still exists, exactly once" \
  "$(grep -c 'readonly property int frameInset:' "$bar_qml" || true)" "1"
check "root.topInset (floating's own, separately-tuned top margin) still exists, exactly once" \
  "$(grep -c 'readonly property real topInset:' "$bar_qml" || true)" "1"
# v2: margins.top resolves per-mode via root.contentTopInset now, not
# root.screenMarginTop directly -- BarPanel's own seam-overlap trick
# (see its own comment) needed a DIFFERENT number for "how far content
# sits from this window's own top edge" than screenMarginTop's own
# (now separate) job of "this window's real final on-screen offset,
# overlap included". Same docked/floating split either property carries,
# just renamed/split apart for the two different jobs.
margins_top_line="$(grep -m1 'position === "top".*barWindow.barRoot.contentTopInset' "$barpanel_qml")"
check "margins.top still resolves per-mode via root.contentTopInset" \
  "$(printf '%s' "$margins_top_line" | grep -c 'barWindow\.barRoot\.contentTopInset' || true)" "1"
# Issue #114 follow-up: floating's own branch now collapses to 0 with
# Frame Border off, same "sit flush at the true edge" treatment the
# notch/shelf already got. Docked is untouched -- resolvedFrameEnabled
# is already forced true whenever docked.
check "root.contentTopInset keeps personal floating spacing independent of the frame" \
  "$(grep -c 'readonly property real contentTopInset: docked ? frameInset : topInset' "$bar_qml" || true)" "1"

# --- root.screenMarginTop (bar hosting infra) --------------------------
#
# v2: this window's own REAL final on-screen top offset, i.e.
# contentTopInset with the seam-overlap trick's own reduction already
# applied for a top-positioned DOCKED bar (0 for left/right/bottom,
# unaffected by the trick). && docked, not unconditional -- direct live
# report ("the hold drag to reorder line... is a bit high on the bar"):
# this was the one real use of seamOverlap that missed the docked gate
# every other use site already carries (margins.top, exclusiveZone,
# contentOffset's own topMargin) -- it kept subtracting seamOverlap
# while floating too, where BarPanel never actually paints/reserves it,
# landing the drag marker exactly seamOverlap too high. Real, reusable
# bar-hosting infrastructure -- currently unconsumed outside this file's
# own drag-ghost correction (a past attempt to use it for quickactions'/
# pluginpins' own PopupCard.margin, calibrated for centerOnBar's
# different Y formula, was verified live to be wrong for the
# target.height-based formula these actually use -- see either widget's
# own popup.margin comment for the real fix).
check "root.screenMarginTop exists, exactly once (bar-hosting infra)" \
  "$(grep -c 'readonly property int screenMarginTop: (position === "top" && docked) ? contentTopInset - seamOverlap : contentTopInset' "$bar_qml" || true)" "1"

# ruixen.quickactions'/ruixen.pluginpins' own popups: centerOnBar stays
# reverted (e0429b7 was purely visual, correctly dropped). The Y position
# needed real live tuning, not a derived formula -- direct live report +
# screenshot confirmed PopupCard's own plain default (target.height +
# margin) landed overlapping the bar's own reserved height above the
# icon row; a since-abandoned analytical fix (fully cancelling
# target.height via PopupCard's own exposed barH) overshot the opposite
# way, into the bar's own reserved-but-invisible padding. 17 is the
# real, live-measured value in between (via a temporary debug hook
# reading popup.anchor.rect.y directly) -- both widgets share this exact
# value since both use the same BarIconButton icon (same real height).
qa_qml="$repo_dir/bars/widgets/ruixen.quickactions/QuickActions.qml"
pp_qml="$repo_dir/bars/widgets/ruixen.pluginpins/BarWidget.qml"
check "ruixen.quickactions' own popup still has no centerOnBar override" \
  "$(grep -c 'centerOnBar:' "$qa_qml" || true)" "0"
check "ruixen.quickactions' own popup uses the live-measured margin" \
  "$(grep -c '    margin: 17' "$qa_qml" || true)" "1"
check "ruixen.pluginpins' own popup uses the live-measured margin" \
  "$(grep -c '    margin: 17' "$pp_qml" || true)" "1"

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ "$fail_count" -eq 0 ]]
