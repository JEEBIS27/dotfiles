{
  config,
  lib,
  pkgs,
  ...
}:
let
  directionBindings = import ../packages/direction-bindings.nix { inherit lib; };
  legacy = config.jeebis.desktop.compositor == "hyprland";
  yaziPlugins = builtins.mapAttrs (_: pin: pkgs.fetchFromGitHub pin) (
    builtins.fromJSON (builtins.readFile ../packages/yazi/sources.json)
  );
in
{
  # Change only this public setting; keep identity and credentials outside Nix.
  home.activation.deltaSharedTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.git}/bin/git config --global delta.syntax-theme Desktop
  '';

  # Native TUIOS saves changes into the last writable include. Defaults stay
  # declarative; local.toml belongs to the user and survives rebuilds.
  home.activation.tuiosLocalConfig = lib.mkIf legacy (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${config.xdg.configHome}/tuios/local.toml" ]; then
        run mkdir -p "${config.xdg.configHome}/tuios"
        run touch "${config.xdg.configHome}/tuios/local.toml"
      fi
    ''
  );
  # Merge only TUIOS-owned hooks; keep Codex history, credentials and other
  # integrations outside Home Manager. SessionStart records each new chat ID.
  home.activation.tuiosCodexHooks = lib.mkIf legacy (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      # TUIOS requires this directory even before the first Codex login.
      # Create only the local state root; do not manage auth or conversation data.
      codex_home="''${CODEX_HOME:-${config.home.homeDirectory}/.codex}"
      run mkdir -p -m 700 "$codex_home"
      run ${config.home.profileDirectory}/bin/tuios integration install codex \
        --no-skill --command "${config.home.profileDirectory}/bin/tuios"
    ''
  );
  xdg.configFile =
    lib.optionalAttrs legacy {
      "omarchy/extensions/omarchy-menu.jsonc".source = ../files/omarchy/extensions/omarchy-menu.jsonc;
      "rio/config.toml".source = ../files/rio/config.toml;
      # Compatibility path for existing launchers; share the main renderer.
      "rio-yazi/config.toml".source = ../files/rio/config.toml;
      "rio-yazi/themes/Desktop.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.jeebis.desktop.themeDirectory}/rio.toml";

      "rio/themes/Desktop.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.jeebis.desktop.themeDirectory}/rio.toml";
      "tuios/config.toml".text = "include = [\"defaults.toml\", \"?local.toml\"]\n";
      # Client-only Codex profile: GUI project names and chats, not the file tree.
      "tuios-codex/tuios/config.toml".text = ''
        include = ["../../tuios/config.toml"]
        [appearance.sidebar]
        enabled = true
        width = 28
        sections = "custom"
        [appearance.sidebar.custom]
        title = "Chats"
        command = "jeebis-codex-sidebar --rows"
        refresh = "5s"
        [appearance.sidebar.left]
        sections = "custom"
        [appearance.sidebar.right]
        sections = "custom"
      '';

      "tuios/defaults.toml".text =
        builtins.replaceStrings [ "@fish@" ] [ "${config.jeebis.shell.package}/bin/fish" ]
          (
            let
              substitute = format: letters: lib.mapAttrs' (k: v: lib.nameValuePair (format k) (format v)) letters;
              keys =
                (substitute (k: ''+${k}"'') directionBindings.modified)
                // (substitute (k: ''"${k}"'') directionBindings.plain);
            in
            builtins.replaceStrings (builtins.attrNames keys) (builtins.attrValues keys) (
              builtins.readFile ../files/tuios/config.toml
            )
          );
    }
    // {
      "bat/themes/Desktop.tmTheme".source =
        config.lib.file.mkOutOfStoreSymlink "${config.jeebis.desktop.themeDirectory}/preview.tmTheme";
      "yazi/flavors/kanagawa.yazi/LICENSE".source = ../files/yazi/flavors/kanagawa.yazi/LICENSE;
      "yazi/flavors/kanagawa.yazi/LICENSE-tmtheme".source =
        ../files/yazi/flavors/kanagawa.yazi/LICENSE-tmtheme;
      "yazi/flavors/kanagawa.yazi/README.md".source = ../files/yazi/flavors/kanagawa.yazi/README.md;
      "yazi/flavors/kanagawa.yazi/flavor.toml".source = ../files/yazi/flavors/kanagawa.yazi/flavor.toml;
      "yazi/flavors/kanagawa.yazi/preview.png".source = ../files/yazi/flavors/kanagawa.yazi/preview.png;
      "yazi/flavors/kanagawa.yazi/tmtheme.xml".source = ../files/yazi/flavors/kanagawa.yazi/tmtheme.xml;
      "yazi/flavors/tokyonight-night.yazi/LICENSE".source =
        ../files/yazi/flavors/tokyonight-night.yazi/LICENSE;
      "yazi/flavors/tokyonight-night.yazi/LICENSE-tmtheme".source =
        ../files/yazi/flavors/tokyonight-night.yazi/LICENSE-tmtheme;
      "yazi/flavors/tokyonight-night.yazi/README.md".source =
        ../files/yazi/flavors/tokyonight-night.yazi/README.md;
      "yazi/flavors/tokyonight-night.yazi/flavor.toml".source =
        ../files/yazi/flavors/tokyonight-night.yazi/flavor.toml;
      "yazi/flavors/tokyonight-night.yazi/preview.png".source =
        ../files/yazi/flavors/tokyonight-night.yazi/preview.png;
      "yazi/flavors/tokyonight-night.yazi/tmtheme.xml".source =
        ../files/yazi/flavors/tokyonight-night.yazi/tmtheme.xml;
      "yazi/plugins/helix-open.yazi/main.lua".source = ../files/yazi/plugins/helix-open.yazi/main.lua;
      "yazi/keymap.toml".source = (pkgs.formats.toml { }).generate "yazi-keymap.toml" (
        import ../packages/yazi/keymap.nix {
          inherit lib;
          settings = builtins.fromTOML (builtins.readFile ../files/yazi/keymap.toml);
          inherit (import ../files/helix/key-layout.nix) directionKeys modifiedDirectionKeys;
        }
      );
      "yazi/plugins/unified-actions.yazi/main.lua".source =
        ../files/yazi/plugins/unified-actions.yazi/main.lua;
      "yazi/plugins/archive-actions.yazi/main.lua".source =
        ../files/yazi/plugins/archive-actions.yazi/main.lua;
      "yazi/plugins/ucp.yazi".source = yaziPlugins.ucp;
      "yazi/plugins/compress.yazi".source = yaziPlugins.compress;
      "yazi/package.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/files/yazi/package.toml";
      "yazi/plugins/unified-layout.yazi/main.lua".source =
        ../files/yazi/plugins/unified-layout.yazi/main.lua;
      "yazi/plugins/unified-motions.yazi/main.lua".source =
        ../files/yazi/plugins/unified-motions.yazi/main.lua;
      "yazi/plugins/unified-tabs.yazi/main.lua".source = ../files/yazi/plugins/unified-tabs.yazi/main.lua;
      "yazi/theme.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.jeebis.desktop.themeDirectory}/yazi.toml";
      "yazi/yazi.toml".source = ../files/yazi/yazi.toml;
      "yazi/plugins/fit-image.yazi/main.lua".source = ../files/yazi/plugins/fit-image.yazi/main.lua;
    };
}
