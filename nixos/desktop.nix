{ appPkgs, pkgs, lib, ... }:
let
  rotation = import ../packages/display-rotation.nix { pkgs = appPkgs; };
  greeterConfig = pkgs.writeText "jeebis-greeter.lua" ''
    hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true }, animations = { enabled = false } })
    hl.on("hyprland.start", function() hl.exec_cmd("${rotation}/bin/jeebis-display-rotation greeter") end)
  '';
  mozkey = import ../packages/mozkey-fcitx5.nix { pkgs = appPkgs; };
  helium = import ../packages/helium.nix { inherit pkgs; };
  loginTheme = import ../packages/jeebis-login-theme.nix { pkgs = appPkgs; };
  fish = import ../packages/fish.nix { pkgs = appPkgs; };
in
{
  time.timeZone = lib.mkDefault "Asia/Tokyo";
  i18n.defaultLocale = lib.mkDefault "ja_JP.UTF-8";
  console.keyMap = lib.mkDefault "jp106";
  services.xserver.xkb.layout = lib.mkDefault "jp";
  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  services.gvfs.enable = true;
  programs.fish.enable = true;
  users.users.jeebis.shell = fish;
  environment.shells = [ fish ];
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = appPkgs.hyprland;
    portalPackage = appPkgs.xdg-desktop-portal-hyprland;
  };
  # A graphical login without installing the Plasma desktop. Use the registered
  # UWSM session so user services receive the Wayland session environment.
  services.displayManager.sddm.enable = lib.mkDefault true;
  services.displayManager.sddm.wayland.enable = lib.mkDefault true;
  services.displayManager.sddm.wayland.compositorCommand = "${appPkgs.hyprland}/bin/start-hyprland -- --config ${greeterConfig}";
  systemd.tmpfiles.rules = [ "d /var/lib/jeebis-theme 0755 jeebis users -" ];
  services.displayManager.sddm.theme = "jeebis-login-theme";
  services.displayManager.sddm.extraPackages = with pkgs.kdePackages; [
    qtsvg qtmultimedia qtvirtualkeyboard
  ];
  services.displayManager.defaultSession = lib.mkDefault "hyprland-uwsm";
  environment.systemPackages = [ loginTheme helium ] ++ (with appPkgs; [
    # gtk-launch is also resolved by applications started through UWSM.
    gtk3 nautilus hyprland-preview-share-picker hyprsunset
    wl-clipboard grim slurp libnotify brightnessctl
  ]);
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
  security.pam.services.tide-island = { };
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.pipewire = { enable = true; pulse.enable = true; alsa.enable = true; };
  security.rtkit.enable = true;
  # User credentials, boot disks and GPU drivers are host-specific.
  # This module is a desktop component, not an installer or hardware profile.
}
