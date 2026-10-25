{ pkgs }:
# Keep the locked nixpkgs source and dependency hash; this is a UI-only patch.
pkgs.tuios.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./tuios/settings-gear.patch ];
})
