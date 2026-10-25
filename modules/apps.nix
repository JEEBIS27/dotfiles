{ appPkgs, config, lib, ... }:
{
  # Keep the app package set pinned separately from Home Manager's module set.
  # Install packages without enabling modules that regenerate existing configs.
  home.packages = with appPkgs; [
    git curl wget
    zsh (import ../packages/tuios.nix { pkgs = appPkgs; }) sheldon
    neovim yazi
    eza bat delta dust fzf zoxide ripgrep fd
    unzip _7zz stow jq
    ffmpeg poppler-utils imagemagick mediainfo exiftool
    gcc gnumake pkg-config
  ] ++ lib.optionals (config.jeebis.desktop.backend == "nixos") (with appPkgs; [
    rio
    # Retained Neovim fallback plugin build runtimes.
    nodejs cargo rustc
  ]);
}
