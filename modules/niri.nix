{ config, lib, pkgs, ... }:
let
  cfg = config.jeebis.desktop;
  applications = import ../files/desktop/applications.nix { inherit config pkgs; };
  catalog = pkgs.writeText "jeebis-desktop-applications.json" (builtins.toJSON applications);
  actions = pkgs.writeShellApplication {
    name = "jeebis-niri";
    runtimeInputs = [ pkgs.python3 pkgs.libnotify ];
    text = ''
      exec python3 ${../packages/desktop/niri-actions.py} --catalog ${catalog} "$@"
    '';
  };
  appBindings = lib.concatStringsSep "\n" (lib.concatLists (lib.mapAttrsToList (id: app:
    lib.optional (id != "terminal")
      ''Mod+Alt+${app.key} { spawn "${actions}/bin/jeebis-niri" "launch" "${id}"; }''
    ++ [ ''Mod+Alt+Shift+${app.key} { spawn "${actions}/bin/jeebis-niri" "launch" "${id}" "--below"; }'' ]
  ) (lib.filterAttrs (_: app: app.key != null) applications)));
  workspaceBindings = lib.concatStringsSep "\n" (map (number:
    let name = toString number; key = if number == 10 then "0" else name;
    in ''
      Mod+${key} { focus-workspace "${name}"; }
      Mod+Shift+${key} { move-window-to-workspace "${name}"; }
    '') (lib.range 1 10));
  workspaces = lib.concatMapStringsSep "\n" (n: ''workspace "${toString n}"'') (lib.range 1 10);
  text = builtins.replaceStrings
    [ "@machine@" "@terminal@" "@desktop@" "@actions@" "@applications@" "@workspace-bindings@" "@workspaces@" ]
    [ config.jeebis.machine.niriConfiguration config.jeebis.terminal.command cfg.command "${actions}/bin/jeebis-niri" appBindings workspaceBindings workspaces ]
    (builtins.readFile ../files/niri/config.kdl);
in {
  config = lib.mkIf (cfg.compositor == "niri") {
    xdg.configFile."niri/config.kdl".text = text;
    xdg.configFile."jeebis/applications.json".source = catalog;
    home.packages = with pkgs; [ actions niri xwayland-satellite btop brightnessctl wireplumber
      slack spotify obsidian nautilus localsend zathura ];
  };
}
