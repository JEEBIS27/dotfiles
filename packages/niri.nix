{ pkgs }:
# CenterWindow on an adjacent inactive column frames that pair without changing
# focus. Upstream ignores this request; the desktop resize helper uses it to
# restore the viewport after paired resizing and full-width round trips.
pkgs.niri.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./desktop/niri-frame-pair.patch ];
})
