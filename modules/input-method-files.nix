{ config, lib, appPkgs, ... }:
let
  native = config.jeebis.desktop.backend == "nixos" && config.jeebis.inputMethod == "mozkey";
  mozkey = import ../packages/mozkey-fcitx5.nix { pkgs = appPkgs; };
in
{
  options.jeebis.inputMethod = lib.mkOption {
    type = lib.types.enum [ "mozkey" "beankey" "hazkey" ];
    default = "mozkey";
  };
  config = {
  # Fcitx rewrites these settings. Keep a writable repository source, not a store file.
  home.packages = lib.optionals native [ mozkey ];
  xdg.configFile = lib.mkIf (config.jeebis.inputMethod == "mozkey") ({
    "mozkey-ibg/config1.db".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Git/home-manager/files/mozkey-ibg/config1.db";
  } // builtins.listToAttrs (map (name: {
    name = "fcitx5/${name}";
    value.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Git/home-manager/files/fcitx5/${name}";
  }) [ "config" "profile" "conf/keyboard.conf" "conf/mozkey-ibg.conf" ]));
  };
}
