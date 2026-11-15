{ pkgs }:
# CenterWindow on an adjacent inactive column frames that pair without changing
# focus. Upstream ignores this request; the desktop resize helper uses it to
# restore the viewport after paired resizing and full-width round trips.
# Full-width splits lock the old tile's outer edge using its animated geometry,
# including while a newly mapped client and the old client commit separately.
pkgs.niri.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./desktop/niri-frame-pair.patch ];
})
