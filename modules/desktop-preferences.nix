{ config, lib, pkgs, ... }:
let native = config.jeebis.desktop.backend == "nixos";
in {
  config = lib.mkMerge [ {
    xdg.configFile."gtk-3.0/gtk.css".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/jeebis-theme/current/gtk.css";
    xdg.configFile."gtk-4.0/gtk.css".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/jeebis-theme/current/gtk.css";
  } (lib.mkIf native {
    home.sessionVariables.BROWSER = "helium";
    gtk = {
      enable = true;
      theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; };
      iconTheme = { name = "Yaru-magenta"; package = pkgs.yaru-theme; };
      font = { name = "Adwaita Sans"; size = 11; package = pkgs.adwaita-fonts; };
    };
    home.pointerCursor = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      icon-theme = "Yaru-magenta";
      cursor-theme = "Adwaita";
      cursor-size = 24;
      font-name = "Adwaita Sans 11";
    };
    qt = {
      enable = true;
      platformTheme.name = "qtct";
      style.name = "Fusion";
      qt5ctSettings.Appearance = { custom_palette = true; color_scheme_path = "${config.xdg.stateHome}/jeebis-theme/current/qt.colors"; icon_theme = "Yaru-magenta"; style = "Fusion"; };
      qt6ctSettings.Appearance = { custom_palette = true; color_scheme_path = "${config.xdg.stateHome}/jeebis-theme/current/qt.colors"; icon_theme = "Yaru-magenta"; style = "Fusion"; };
    };
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ "helium.desktop" ];
        "x-scheme-handler/http" = [ "helium.desktop" ];
        "x-scheme-handler/https" = [ "helium.desktop" ];
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
      };
    };
  }) ];
}
