{ appPkgs, config, lib, pkgs, ... }:
let
  app = import ../packages/herdr-app.nix { inherit pkgs; };
  colors = builtins.fromTOML (builtins.readFile ../files/desktop/themes/kanagawa.toml);
  fallback = pkgs.writeText "jeebis-herdr-initial-theme.json" (builtins.toJSON {
    inherit (colors) background foreground;
    cursor = colors.foreground;
    selection = colors.selection;
    ansi = map (name: colors.${name}) [ "background" "red" "green" "yellow" "blue" "magenta" "cyan" "foreground"
      "muted" "bright_red" "bright_green" "bright_yellow" "bright_blue" "bright_magenta" "bright_cyan" "bright_foreground" ];
  });
  preferences = pkgs.writeText "jeebis-herdr-preferences.json" (builtins.toJSON {
    settings = { core = "${app.core}/bin/herdr-core"; theme = "jeebis"; font = "HackGen35 Console NF"; font_size = 14; };
    programs.programs.codex.run = [ "${appPkgs.codex}/bin/codex" "--no-daemon" ];
  });
  launcher = pkgs.writeShellApplication {
    name = "jeebis-agents";
    text = ''
      exec ${app}/bin/herdr-app "$@"
    '';
  };
in {
  home.packages = [ app app.core launcher ];
  xdg.desktopEntries.jeebis-agents = {
    name = "Herdr App";
    comment = "AI coding workspaces";
    exec = "${launcher}/bin/jeebis-agents";
    icon = "herdr-app";
    terminal = false;
    categories = [ "Development" ];
    settings.StartupWMClass = "herdr-app";
  };
  home.activation.configureHerdr = lib.hm.dag.entryAfter [ "initializeDesktopTheme" "refreshDesktopAppearance" ] ''
    theme="${config.xdg.stateHome}/jeebis-theme/current/herdr-theme.json"
    if [ ! -f "$theme" ]; then theme="${fallback}"; fi
    run ${pkgs.python3}/bin/python3 ${../packages/desktop/herdr-config.py} \
      --root ${lib.escapeShellArg "${config.xdg.configHome}/herdr-app"} \
      --preferences ${preferences} --theme "$theme"
  '';
  # App settings, agent credentials, integration state and sessions remain local.
}
