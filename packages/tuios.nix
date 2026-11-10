{ pkgs }:
let
  # Shared logical-to-physical layout; Ctrl/Alt chords and literal input stay native.
  letters = import ./key-layout.nix {
    inherit (pkgs) lib;
    inherit (import ../files/helix/key-layout.nix) directionKeys;
  };
  copyKeys = pkgs.writeText "tuios-copy-keys.go" ''
    package input

    // Generated from the same layout as Helix and Yazi. Called only after
    // literal character-search input has been handled, never during search text.
    func copyModeLogicalKey(key string) string {
      switch key {
    ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (logical: physical:
      "case ${builtins.toJSON physical}: return ${builtins.toJSON logical}"
    ) letters)}
      default: return key
      }
    }
  '';
in
# Keep the locked nixpkgs source and dependency hash.
pkgs.tuios.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./tuios/settings-gear.patch
    ./tuios/copy-mode-layout.patch
  ];
  postPatch = (old.postPatch or "") + ''
    cp ${copyKeys} internal/input/copymode_layout.go
  '';
})
