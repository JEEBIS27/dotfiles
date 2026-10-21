{ config, lib, appPkgs, ... }:
let
  native = config.jeebis.desktop.backend == "nixos";
  mozkey = import ../packages/mozkey-fcitx5.nix { pkgs = appPkgs; };
in
{
  # Fcitx rewrites these settings. Keep a writable repository source, not a store file.
  home.packages = lib.optionals native [ mozkey ];
  systemd.user.services = lib.optionalAttrs native {
    fcitx5 = {
      Unit = { Description = "Mozkey IbG / Fcitx5"; After = [ "graphical-session-pre.target" "wayland-session-waitenv.service" ]; PartOf = [ "graphical-session.target" ]; };
      Service = { ExecStart = "${mozkey}/bin/fcitx5 -D"; Restart = "on-failure"; RestartSec = 2; };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
  xdg.configFile = {
    "mozkey-ibg/config1.db".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Git/home-manager/files/mozkey-ibg/config1.db";
  } // builtins.listToAttrs (map (name: {
    name = "fcitx5/${name}";
    value.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Git/home-manager/files/fcitx5/${name}";
  }) [ "config" "profile" "conf/keyboard.conf" "conf/mozkey-ibg.conf" ]);
}
