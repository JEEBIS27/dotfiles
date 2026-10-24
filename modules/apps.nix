{ appPkgs, config, lib, ... }:
{
  # Keep the app package set pinned separately from Home Manager's module set.
  # Install packages without enabling modules that regenerate existing configs.
  home.packages = with appPkgs; [
    git curl wget
    zsh tuios sheldon
    neovim yazi
    eza bat delta dust fzf zoxide ripgrep fd
    unzip _7zz stow jq
    ffmpeg poppler-utils imagemagick mediainfo exiftool
    gcc gnumake pkg-config
  ] ++ lib.optionals (config.jeebis.desktop.backend == "nixos") (with appPkgs; [
    rio
    # Match the enabled Neovim servers and formatters with Nix-built binaries.
    lua-language-server stylua shfmt
    gopls biome prisma-language-server tailwindcss-language-server
    vtsls vue-language-server vscode-langservers-extracted
    jsonnet-language-server yaml-language-server bash-language-server
    buf dockerfile-language-server-nodejs graphql-language-service-cli
    nixd pyright prettierd nixfmt
    # Copilot and native plugin builds need these runtimes/toolchains.
    nodejs cargo rustc
  ]);
}
