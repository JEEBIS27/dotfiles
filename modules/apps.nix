{ appPkgs, config, lib, ... }:
{
  # Keep the app package set pinned separately from Home Manager's module set.
  # Install packages without enabling modules that regenerate existing configs.
  imports = [ ./cli.nix ];
  home.packages = [
    (import ../packages/tuios.nix { pkgs = appPkgs; })
  ] ++ lib.optionals (config.jeebis.desktop.backend == "nixos") (with appPkgs; [
    rio
    # Retained Neovim fallback plugin build runtimes.
    nodejs cargo rustc
  ]);
}
