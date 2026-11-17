{ lib, pkgs, ... }: {
  programs.niri.enable = true;
  programs.niri.package = import ../packages/niri.nix { inherit pkgs; };
  # niri imports the display environment before reporting session readiness.
  systemd.user.services.fcitx5.after = [ "niri.service" ];
  # The standard NixOS session has no Hyprland/UWSM requirement.
  programs.hyprland.enable = lib.mkForce false;
  programs.hyprland.withUWSM = lib.mkForce false;
  programs.xwayland.enable = true;
  environment.systemPackages = [ pkgs.xwayland-satellite ];
  # Niri's NixOS module supplies the session units and GNOME/GTK portals.
  services.displayManager.defaultSession = lib.mkForce "niri";
  # SDDM uses an independent Weston kiosk compositor for the login screen.
  home-manager.users.jeebis.jeebis.desktop.compositor = "niri";
}
