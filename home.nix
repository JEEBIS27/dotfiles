{ ... }:

{
  imports = [ ./modules/zsh-files.nix ./modules/apps.nix ./modules/app-files.nix ./modules/desktop.nix ./modules/mounts.nix ./modules/input-method-files.nix ];

  home.username = "jeebis";
  home.homeDirectory = "/home/jeebis";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Keep the existing OS providers for man and the MIME database tools.
  # Personal MIME associations can still be migrated as configuration files.
  programs.man.enable = false;
  xdg.mime.enable = false;

}
