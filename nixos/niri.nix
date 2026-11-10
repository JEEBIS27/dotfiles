{ lib, pkgs, ... }: {
  programs.niri.enable = true;
  # The standard NixOS session has no Hyprland/UWSM requirement.
  programs.hyprland.enable = lib.mkForce false;
  programs.hyprland.withUWSM = lib.mkForce false;
  programs.xwayland.enable = true;
  environment.systemPackages = [ pkgs.xwayland-satellite ];
  # Niri's NixOS module supplies the session units and GNOME/GTK portals.
  services.displayManager.defaultSession = lib.mkForce "niri";
  # SDDM has its own small compositor; no Hyprland is needed by the greeter.
  services.displayManager.sddm.wayland.compositorCommand = lib.mkForce
    "${pkgs.weston}/bin/weston --shell=kiosk-shell.so";
  home-manager.users.jeebis.jeebis.desktop.compositor = "niri";
}
