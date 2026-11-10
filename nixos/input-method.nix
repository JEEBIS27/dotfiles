{ config, lib, ... }:
let cfg = config.jeebis.inputMethod;
in {
  options.jeebis.inputMethod = lib.mkOption {
    type = lib.types.enum [ "mozkey" "beankey" "hazkey" ];
    default = "mozkey";
    description = "Japanese IME; beanKey is the first Wayland migration candidate.";
  };
  config = lib.mkMerge [ {
    home-manager.users.jeebis.jeebis.inputMethod = cfg;
  } (lib.mkIf (cfg == "beankey") {
    programs.beanKey.enable = true;
    i18n.inputMethod.fcitx5.waylandFrontend = true;
  }) (lib.mkIf (cfg == "hazkey") {
    i18n.inputMethod = { enable = true; type = "fcitx5"; fcitx5.waylandFrontend = true; };
    services.hazkey.enable = true;
  }) ];
}
