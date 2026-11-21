{
  config,
  lib,
  pkgs,
  ...
}:
let
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
