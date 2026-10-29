{ config, lib, appPkgs, ... }:
let steel = import ../packages/helix-steel { pkgs = appPkgs; };
in
{
  # The single default-editor definition. This sets standard EDITOR and VISUAL.
  programs.helix = {
    enable = true;
    package = steel.editor;
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

  # Install servers used by Helix's bundled language definitions. Optional
  # alternatives in those definitions need not all be installed.
  home.packages = with appPkgs; [
    lua-language-server shfmt go gopls
    typescript-language-server prisma-language-server
    vscode-langservers-extracted jsonnet-language-server
    yaml-language-server bash-language-server
    buf dockerfile-language-server graphql-language-service-cli
    nil nixfmt ty ruff
    # Vue is the only server/formatter integration beyond bundled defaults.
    vtsls vue-language-server prettierd
  ];

  xdg.configFile."helix/init.scm".text = builtins.replaceStrings
    [ "@fish@" ] [ "${config.jeebis.shell.package}/bin/fish" ]
    (builtins.readFile ../files/helix/steel/init.scm);
  xdg.configFile."helix/helix.scm".source = ../files/helix/steel/helix.scm;
  # Keep cogs/ writable: Steel generates its own helix/ API modules there.
  # Only the individual third-party plugin directories are immutable links.
  xdg.dataFile = builtins.listToAttrs (map (name: {
    name = "jeebis-helix-steel/cogs/${name}";
    value.source = "${steel.plugins}/${name}";
  }) [ "flash" "steel-pty" "recentf" "microscope" "matte.hx" "notify" "moka" "glyph" "yazi" ]) // {
    "jeebis-helix-steel/native/libsteel_pty.so".source =
      "${steel.terminal}/lib/libsteel_pty.so";
  };
  home.file.".local/bin/jeebis-helix-yazi" = {
    executable = true;
    text = builtins.replaceStrings [ "@yazi@" "/usr/bin/env python3" ]
      [ "${appPkgs.yazi}/bin/yazi" "${appPkgs.python3}/bin/python3" ]
      (builtins.readFile ../files/desktop/helpers/jeebis-helix-yazi);
  };

  xdg.configFile."helix/themes/Desktop.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.jeebis.desktop.themeDirectory}/helix.toml";

  # The compositor's launch environment must agree with login shells.
  xdg.configFile."jeebis/editor.lua".text = ''
    hl.env("EDITOR", ${builtins.toJSON config.home.sessionVariables.EDITOR})
    hl.env("VISUAL", ${builtins.toJSON config.home.sessionVariables.VISUAL})
  '';

  # This is the standard file read by omarchy-launch-editor (hx is supported).
  home.file.".local/state/omarchy/defaults/editor" =
    lib.mkIf (config.jeebis.desktop.backend == "omarchy") {
      text = config.home.sessionVariables.EDITOR + "\n";
    };
}
