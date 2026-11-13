{ config, lib, pkgs, ... }:
let
  cfg = config.jeebis.desktop;
  niri = import ../packages/niri.nix { inherit pkgs; };
  spotify = import ../packages/spotify.nix { inherit pkgs; };
  applications = import ../files/desktop/applications.nix { inherit config pkgs; };
  catalog = pkgs.writeText "jeebis-desktop-applications.json" (builtins.toJSON applications);
  actions = pkgs.writeShellApplication {
    name = "jeebis-niri";
    runtimeInputs = [ pkgs.python3 pkgs.libnotify resize ];
    text = ''
      exec python3 ${../packages/desktop/niri-actions.py} --catalog ${catalog} "$@"
    '';
  };
  resize = pkgs.writeShellApplication {
    name = "jeebis-niri-resize";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../packages/desktop/niri_resize.py} "$@"
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
    [ "@machine@" "@terminal@" "@desktop@" "@actions@" "@applications@" "@workspace-bindings@" "@workspaces@" "@resize@" ]
    [ config.jeebis.machine.niriConfiguration config.jeebis.terminal.command cfg.command "${actions}/bin/jeebis-niri" appBindings workspaceBindings workspaces "${resize}/bin/jeebis-niri-resize" ]
    (builtins.readFile ../files/niri/config.kdl);
in {
  config = lib.mkIf (cfg.compositor == "niri") {
    systemd.user.services.jeebis-niri-auto-width = {
      Unit = {
        Description = "Niri single-window width and settled resize compensation";
        After = [ "wayland-session-waitenv.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.python3}/bin/python3 ${../packages/desktop}/niri-auto-width.py";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    xdg.configFile."niri/config.kdl".text = text;
    xdg.configFile."jeebis/applications.json".source = catalog;
    home.packages = with pkgs; [ actions resize niri xwayland-satellite btop brightnessctl wireplumber
      slack obsidian nautilus localsend zathura ] ++ [ spotify ];
  };
}
