{ appPkgs, ... }:
{
  # Shared terminal tools only: no compositor, systemd, IME or host paths.
  home.packages = with appPkgs; [
    git curl wget just
    # fish is supplied by programs.fish.
    neovim yazi
    eza bat delta dust fzf zoxide ripgrep fd
    unzip _7zz stow jq
    ffmpeg poppler-utils imagemagick mediainfo exiftool
    gcc gnumake pkg-config
  ];
}
