{ appPkgs, config, lib, pkgs, ... }:
{
  # Keep the app package set pinned separately from Home Manager's module set.
  # Install packages without enabling modules that regenerate existing configs.
  imports = [ ./cli.nix ];
  home.file.".local/bin/matlab-nix".source =
    "${import ../packages/matlab.nix { inherit pkgs; }}/bin/matlab-nix";
  xdg.desktopEntries.matlab-nix = {
    name = "MATLAB R2026b";
    genericName = "Scientific Computing";
    comment = "MATLAB in the Nix runtime environment";
    exec = "${config.home.homeDirectory}/.local/bin/matlab-nix";
    icon = "${config.home.homeDirectory}/MATLAB/R2026b/bin/glnxa64/cef_resources/matlab_icon.png";
    terminal = false;
    categories = [ "Education" "Science" "Math" ];
    startupNotify = false;
    settings.StartupWMClass = "MATLAB R2026b Update 1";
  };
  home.packages = [
    appPkgs.codex
  ] ++ lib.optionals (config.jeebis.desktop.compositor == "hyprland") [
    (import ../packages/tuios.nix { pkgs = appPkgs; })
  ] ++ lib.optionals (config.jeebis.desktop.backend == "nixos") (with appPkgs; [
    # Retained Neovim fallback plugin build runtimes.
    nodejs cargo rustc
  ]);
}
