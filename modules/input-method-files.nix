{ config, lib, pkgs, ... }:
let
  profile = pkgs.writeText "mejiroime-fcitx5-profile" ''
    [Groups/0]
    Name=Default
    Default Layout=jp
    DefaultIM=mejiroime

    [Groups/0/Items/0]
    Name=keyboard-jp
    Layout=

    [Groups/0/Items/1]
    Name=mejiroime
    Layout=

    [GroupOrder]
    0=Default
  '';
in {
  # Fcitx owns its mutable profile. Seed a new NixOS profile, never a store symlink.
  # Learning, dictionaries and private preferences are left untouched.
  home.activation.initializeMejiroProfile = lib.mkIf (config.jeebis.desktop.backend == "nixos")
    (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      target=${lib.escapeShellArg "${config.xdg.configHome}/fcitx5/profile"}
      if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        run mkdir -p "$(dirname "$target")"
        run install -m 600 ${profile} "$target"
      fi
    '');
}
