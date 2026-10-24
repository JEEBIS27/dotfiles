{ config, lib, pkgs, appPkgs, ... }:
let
  cfg = config.jeebis.desktop;
  native = cfg.backend == "nixos";
  quickshell = import ../packages/quickshell.nix { pkgs = appPkgs; };
  runtime = import ../packages/desktop/runtime.nix { pkgs = appPkgs; };
  themeDir = "${config.xdg.stateHome}/${if native then "jeebis-desktop" else "omarchy"}/current/theme";
  coreSource = ../files/desktop;
  ruixen = import ../packages/jeebis-shell.nix { pkgs = appPkgs; inherit native; };
  presetDefinitions = builtins.fromJSON (builtins.readFile ../files/desktop/presets.json);
  presetFiles = builtins.listToAttrs (map (preset: {
    name = "omarchy/themes/${preset.name}/colors.toml";
    value.source = coreSource + "/themes/${preset.palette}.toml";
  }) presetDefinitions);
  hostConfigDir = if native then "jeebis-desktop" else "omarchy";
  json = pkgs.writeText "jeebis-desktop-host.json" (builtins.toJSON {
    backend = cfg.backend;
    runtime = toString runtime;
    backgrounds = "${coreSource}/backgrounds";
    themes = "${coreSource}/themes";
    presets = presetDefinitions;
    templates = toString templates;
    renderer = "${../packages/desktop}/render-theme.sh";
    omarchyCycle = "${../packages/desktop}/omarchy-theme-cycle.sh";
    commands = {
      terminal = "jeebis-terminal"; browser = if native then "chromium" else "helium"; editor = "nvim";
    };
  });
  templates = pkgs.runCommand "jeebis-theme-templates" { } ''
    mkdir -p "$out"
    cp ${coreSource}/templates/* "$out/"
    chmod -R u+w "$out"
    substituteInPlace "$out/yazi.toml.tpl" --replace-fail '@themeDir@' '${themeDir}'
  '';
  aliases = builtins.fromJSON (builtins.readFile ../packages/desktop/compat-names.json);
  nativeDeps = [ quickshell ] ++ (with appPkgs; [
    hyprland uwsm grim slurp wl-clipboard libnotify brightnessctl
    wireplumber pulseaudio networkmanager bluez power-profiles-daemon upower
    ffmpeg curl fastfetch cava qt6.qtmultimedia
    fuzzel xdg-utils ddcutil iputils iw fontconfig dbus systemd procps python3 util-linux file hyprsunset inotify-tools findutils libxkbcommon
  ]);
  package = pkgs.runCommand "jeebis-desktop-${cfg.backend}" { } ''
    mkdir -p "$out/bin"
    cat > "$out/bin/jeebis-desktop" <<'SH'
#!${pkgs.runtimeShell}
export PATH="${lib.makeBinPath ([ appPkgs.python3 pkgs.bash pkgs.coreutils pkgs.gawk pkgs.gnused pkgs.gnugrep pkgs.util-linux appPkgs.jq ] ++ lib.optionals native nativeDeps)}:$HOME/.nix-profile/bin:$PATH"
export PATH="$(dirname "$0"):$PATH"
${lib.optionalString native ''export PATH="$(dirname "$0"):${runtime}/bin:$PATH"; export OMARCHY_PATH="${runtime}"''}
exec ${appPkgs.python3}/bin/python3 ${../packages/desktop/desktopctl.py} --config ${json} "$@"
SH
    chmod +x "$out/bin/jeebis-desktop"
    cat > "$out/bin/jeebis-theme-colors" <<'SH'
#!${pkgs.runtimeShell}
export PATH="${lib.makeBinPath [ pkgs.bash pkgs.gawk pkgs.coreutils ]}:$PATH"
exec ${pkgs.bash}/bin/bash ${../packages/desktop/theme-colors.sh} "$@"
SH
    chmod +x "$out/bin/jeebis-theme-colors"
    ${lib.concatMapStringsSep "\n" (entry: ''
      cat > "$out/bin/${entry.name}" <<SH
#!${pkgs.runtimeShell}
exec "$out/bin/jeebis-desktop" ${entry.action} "\$@"
SH
      chmod +x "$out/bin/${entry.name}"
    '') [
      { name = "jeebis-ruixen-theme-set"; action = "theme set"; }
      { name = "jeebis-ruixen-theme-pick"; action = "theme pick"; }
      { name = "jeebis-ruixen-theme-list"; action = "theme list"; }
      { name = "jeebis-ruixen-wallpaper-set"; action = "wallpaper set"; }
      { name = "jeebis-ruixen-wallpaper-pick"; action = "wallpaper pick"; }
    ]}
    ${lib.optionalString native ''
      ${lib.concatMapStringsSep "\n" (name: ''
        cat > "$out/bin/${name}" <<SH
#!${pkgs.runtimeShell}
exec "$out/bin/jeebis-desktop" legacy ${lib.escapeShellArg name} "\$@"
SH
        chmod +x "$out/bin/${name}"
      '') aliases}
      cat > "$out/bin/jeebis-shell" <<'SH'
#!${pkgs.runtimeShell}
export OMARCHY_PATH="${runtime}"
export QML_IMPORT_PATH="${appPkgs.qt6.qtmultimedia}/${appPkgs.qt6.qtbase.qtQmlPrefix}:$QML_IMPORT_PATH"
export QT_PLUGIN_PATH="${appPkgs.qt6.qtmultimedia}/${appPkgs.qt6.qtbase.qtPluginPrefix}:$QT_PLUGIN_PATH"
export PATH="$(dirname "$0"):${lib.makeBinPath (nativeDeps ++ [ pkgs.bash pkgs.coreutils pkgs.gawk pkgs.gnused pkgs.gnugrep appPkgs.jq ])}:$HOME/.nix-profile/bin:${runtime}/bin:$PATH"
exec ${quickshell}/bin/quickshell -n -p ${runtime}/shell "$@"
SH
      chmod +x "$out/bin/jeebis-shell"
    ''}
  '';
  personalHelpers = pkgs.runCommand "jeebis-personal-desktop-helpers" { nativeBuildInputs = [ pkgs.bash appPkgs.python3 ]; } ''
    mkdir -p "$out"
    cp ${coreSource}/helpers/* "$out/"
    chmod +wx "$out/"*
    patchShebangs "$out"
  '';
  # Monitor setup stays local. Personal look-and-feel is managed from files/hypr.
  hyprFiles = builtins.filter (path: !(builtins.elem (builtins.baseNameOf path) [ "monitors.lua" ])) (lib.filesystem.listFilesRecursive ../files/hypr);
  relative = base: path: lib.removePrefix ((toString base) + "/") (toString path);
  fileLinks = builtins.listToAttrs (map (path: {
    name = "hypr/${relative ../files/hypr path}";
    value.source = path;
  }) hyprFiles);
in
{
  options.jeebis.desktop = {
    backend = lib.mkOption { type = lib.types.enum [ "omarchy" "nixos" ]; description = "Host implementation, selected by the flake output."; };
    themeDirectory = lib.mkOption { type = lib.types.str; readOnly = true; default = themeDir; };
    command = lib.mkOption { type = lib.types.str; readOnly = true; default = "${package}/bin/jeebis-desktop"; };
  };
  config = {
    home.packages = [ package appPkgs.fuzzel appPkgs.cava appPkgs.fastfetch ];
    xdg.dataFile."ruixen-shell/hyprland".source = ruixen + /hyprland;
    xdg.dataFile."jeebis-desktop/backgrounds".source = coreSource + /backgrounds;
    xdg.configFile = fileLinks // {
      "jeebis/desktop.lua".text = ''
        local M = {}
        local function quote(s) return o.shell_quote(s) end
        function M.command(...)
          local argv = { ${builtins.toJSON cfg.command}, ... }
          for i, value in ipairs(argv) do argv[i] = quote(value) end
          return table.concat(argv, " ")
        end
        function M.bootstrap() dofile(${builtins.toJSON (if native then "${runtime}/default/hypr/bootstrap.lua" else "/usr/share/omarchy/default/hypr/bootstrap.lua")}) end
        function M.defaults() require("default.hypr.omarchy") end
        function M.toggles() require("default.hypr.toggles") end
        function M.bind(...) return o.bind(...) end
        return M
      '';
      "jeebis/curvature.lua".source = ruixen + /hyprland/jeebis-curvature.lua;
      "${hostConfigDir}/plugins".source = ruixen + /plugins;
      "${hostConfigDir}/shell.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Git/home-manager/files/desktop/jeebis-shell.json";
    }
    // lib.optionalAttrs (!native) (presetFiles // {
      "omarchy/themed/palette.lua.tpl".source = templates + /palette.lua.tpl;
      "omarchy/themed/preview.tmTheme.tpl".source = templates + /preview.tmTheme.tpl;
      "omarchy/themed/yazi.toml.tpl".source = templates + /yazi.toml.tpl;
      "omarchy/themed/rio.toml.tpl".source = templates + /rio.toml.tpl;
      "omarchy/hooks/theme-set.d/refresh-rio.hook" = { source = ../files/omarchy/hooks/theme-set.d/refresh-rio.hook; executable = true; };
      "omarchy/hooks/theme-set.d/refresh-bat.hook" = { source = ../files/omarchy/hooks/theme-set.d/refresh-bat.hook; executable = true; };
    });
    home.file.".local/bin/jeebis-terminal" = { source = personalHelpers + /jeebis-terminal; executable = true; };
    home.file.".local/bin/jeebis-tuios" = { source = personalHelpers + /jeebis-tuios; executable = true; };
    home.file.".local/bin/jeebis-tuios-worktree" = { source = personalHelpers + /jeebis-tuios-worktree; executable = true; };
    home.file.".local/bin/jeebis-codex-tuios" = { source = personalHelpers + /jeebis-codex-tuios; executable = true; };
    home.file.".local/bin/jeebis-chatgpt-new-window" = { source = personalHelpers + /jeebis-chatgpt-new-window; executable = true; };
    home.file.".local/bin/jeebis-theme-cycle" = { text = "#!${pkgs.runtimeShell}\nexec ${cfg.command} theme cycle\n"; executable = true; };
    home.activation = {
      initializeRuixenHypr = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run mkdir -p "$HOME/.config/hypr"
      if [ ! -e "$HOME/.config/hypr/monitors.lua" ]; then
        run install -m644 ${../files/hypr/monitors.lua} "$HOME/.config/hypr/monitors.lua"
      fi
    '';
    } // lib.optionalAttrs native {
      initializeDesktopTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${package}/bin/jeebis-desktop theme init
      '';
    };
    systemd.user.services = lib.optionalAttrs native {
      jeebis-sleep-lock = {
        Unit = { Description = "Lock shared desktop before suspend"; After = [ "jeebis-desktop.service" ]; PartOf = [ "graphical-session.target" ]; };
        Service = { ExecStart = "${package}/bin/jeebis-desktop legacy omarchy-system-sleep-monitor"; Restart = "always"; RestartSec = 2; };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      jeebis-desktop = {
        Unit = { Description = "Jeebis shared desktop shell"; After = [ "graphical-session-pre.target" "wayland-session-waitenv.service" ]; PartOf = [ "graphical-session.target" ]; };
        Service = { ExecStart = "${package}/bin/jeebis-shell"; Restart = "on-failure"; RestartSec = 2; };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
