{ config, lib, pkgs, appPkgs, ... }:
{
  # The single default-editor definition. This sets standard EDITOR and VISUAL.
  programs.helix = {
    enable = true;
    package = appPkgs.helix;
    defaultEditor = true;
    settings = builtins.fromTOML (builtins.readFile ../files/helix/config.toml);
    languages = let
      parsed = builtins.fromTOML (builtins.readFile ../files/helix/languages.toml);
    in lib.recursiveUpdate parsed {
      language-server.vtsls.config.vtsls.tsserver.globalPlugins = map
        (plugin: plugin // {
          location = "${appPkgs.vue-language-server}/lib/language-tools/packages/language-server";
        }) parsed.language-server.vtsls.config.vtsls.tsserver.globalPlugins;
    };
  };

  # Shared language tools, usable by Helix and the retained Neovim fallback.
  # Do not depend on Neovim/Mason's private executable directory.
  home.packages = with appPkgs; [
    lua-language-server stylua shfmt go gopls gotools
    biome prisma-language-server tailwindcss-language-server
    vtsls vue-language-server vscode-langservers-extracted
    jsonnet-language-server yaml-language-server bash-language-server
    buf dockerfile-language-server graphql-language-service-cli
    nixd pyright prettierd nixfmt
  ];

  xdg.configFile."helix/themes/Desktop.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.jeebis.desktop.themeDirectory}/helix.toml";

  # The compositor's launch environment must agree with login shells.
  xdg.configFile."jeebis/editor.lua".text = ''
    hl.env("EDITOR", ${builtins.toJSON config.home.sessionVariables.EDITOR})
    hl.env("VISUAL", ${builtins.toJSON config.home.sessionVariables.VISUAL})
  '';

  # This is the standard file read by omarchy-launch-editor (hx is supported).
  home.file = lib.optionalAttrs (config.jeebis.desktop.backend == "omarchy") {
    ".local/state/omarchy/defaults/editor".text = config.home.sessionVariables.EDITOR + "\n";
  };
}
