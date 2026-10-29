{ appPkgs, pkgs, lib, ... }:
let
  mozkey = import ../packages/mozkey-fcitx5.nix { pkgs = appPkgs; };
  fish = import ../packages/fish.nix { pkgs = appPkgs; };
in
{
  programs.fish.enable = true;
  users.users.jeebis.shell = fish;
  environment.shells = [ fish ];
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = appPkgs.hyprland;
    portalPackage = appPkgs.xdg-desktop-portal-hyprland;
  };
  environment.systemPackages = with appPkgs; [
    chromium nautilus hyprland-preview-share-picker hyprsunset
    wl-clipboard grim slurp libnotify brightnessctl
  ];
  fonts.packages = [ appPkgs.hackgen-nf-font ];
  fonts.fontconfig.defaultFonts.monospace = [ "HackGen35 Console NF" ];
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    package = lib.mkForce mozkey;
    fcitx5.waylandFrontend = true;
  };
  environment.variables.QT_PLUGIN_PATH = lib.mkForce [ "${mozkey}/${appPkgs.qt6.qtbase.qtPluginPrefix}" ];
  programs.fuse.enable = true;
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  security.polkit.enable = true;
  security.pam.services.omarchy-lock-password = { };
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.pipewire = { enable = true; pulse.enable = true; alsa.enable = true; };
  security.rtkit.enable = true;
  # User credentials, boot disks and GPU drivers are host-specific.
  # This module is a desktop component, not an installer or hardware profile.
}
