{ appPkgs, ... }:
{
  # Shared terminal tools only: no compositor, systemd, IME or host paths.
  home.packages = with appPkgs; [
    git
    gh
    gh-dash
    curl
    wget
    just
    nh
    nix-init
    nix-update
    nurl
    statix
    deadnix
    # fish is supplied by programs.fish.
    yazi
    fastfetch
    eza
    bat
    delta
    dust
    fzf
    zoxide
    ripgrep
    fd
    unzip
    _7zz
    zip
    gnutar
    gzip
    xz
    bzip2
    zstd
    coreutils
    stow
    jq
    ffmpeg
    poppler-utils
    imagemagick
    mediainfo
    exiftool
    gcc
    gnumake
    pkg-config
  ];
}
