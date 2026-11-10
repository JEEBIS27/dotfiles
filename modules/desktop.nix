{ config, lib, pkgs, appPkgs, ... }:
let
  cfg = config.jeebis.desktop;
  native = cfg.backend == "nixos";
  legacy = cfg.compositor == "hyprland";
  rotation = import ../packages/display-rotation.nix { pkgs = appPkgs; };
  quickshell = import ../packages/quickshell.nix { pkgs = appPkgs; };
  runtime = if legacy then import ../packages/desktop/runtime.nix { pkgs = appPkgs; } else null;
  themeDir = "${config.xdg.stateHome}/${if native then "jeebis-desktop" else "omarchy"}/current/theme";
  coreSource = ../files/desktop;
  tide = import ../packages/tide-island.nix { pkgs = appPkgs; withNiri = cfg.compositor == "niri"; };
  presetDefinitions = builtins.fromJSON (builtins.readFile ../files/desktop/presets.json);
  presetFiles = builtins.listToAttrs (map (preset: {
    name = "omarchy/themes/${preset.name}/colors.toml";
    value.source = coreSource + "/themes/${preset.palette}.toml";
  }) presetDefinitions);
  hostConfigDir = if native then "jeebis-desktop" else "omarchy";
  json = pkgs.writeText "jeebis-desktop-host.json" (builtins.toJSON {
    backend = cfg.backend;
    compositor = cfg.compositor;
    shell = "tide";
    shellPath = "${tide}/share/tide-island";
    loginAssets = if native then "/var/lib/jeebis-theme" else null;
    runtime = if legacy then toString runtime else null;
    backgrounds = "${coreSource}/backgrounds";
    themes = "${coreSource}/themes";
    presets = presetDefinitions;
    templates = toString templates;
    renderer = "${../packages/desktop}/render-theme.sh";
    herdrConfig = "${config.xdg.configHome}/herdr-app";
    ghosttyReload = "${config.home.profileDirectory}/bin/jeebis-ghostty-reload";
    helixReload = "${personalHelpers}/jeebis-helix-reload";
    omarchyCycle = "${../packages/desktop}/omarchy-theme-cycle.sh";
    commands = {
      niri = if cfg.compositor == "niri" then "${pkgs.niri}/bin/niri" else "niri";
      quickshell = "${quickshell}/bin/quickshell"; terminal = config.jeebis.terminal.command; browser = "helium"; editor = config.home.sessionVariables.EDITOR;
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
    gtk3 grim slurp wl-clipboard libnotify brightnessctl
    wireplumber pulseaudio networkmanager bluez power-profiles-daemon upower
    mpvpaper swayidle ffmpeg curl fastfetch cava qt6.qtmultimedia
    fuzzel xdg-utils ddcutil iputils iw fontconfig dbus systemd procps python3 util-linux file inotify-tools findutils libxkbcommon
  ]) ++ lib.optionals (cfg.compositor == "hyprland") [ appPkgs.hyprland appPkgs.uwsm appPkgs.hyprsunset ];
  package = pkgs.runCommand "jeebis-desktop-${cfg.backend}" { } ''
    mkdir -p "$out/bin"
    cat > "$out/bin/jeebis-desktop" <<'SH'
#!${pkgs.runtimeShell}
export PATH="${lib.makeBinPath ([ appPkgs.python3 pkgs.bash pkgs.coreutils pkgs.gawk pkgs.gnused pkgs.gnugrep pkgs.util-linux appPkgs.jq ] ++ lib.optionals native nativeDeps)}:$HOME/.nix-profile/bin:$PATH"
export PATH="$(dirname "$0"):$PATH"
${lib.optionalString (native && legacy) ''export PATH="$(dirname "$0"):${runtime}/bin:$PATH"; export OMARCHY_PATH="${runtime}"''}
exec ${appPkgs.python3}/bin/python3 ${../packages/desktop}/desktopctl.py --config ${json} "$@"
SH
    chmod +x "$out/bin/jeebis-desktop"
    cat > "$out/bin/jeebis-theme-colors" <<'SH'
#!${pkgs.runtimeShell}
export PATH="${lib.makeBinPath [ pkgs.bash pkgs.gawk pkgs.coreutils ]}:$PATH"
exec ${pkgs.bash}/bin/bash ${../packages/desktop/theme-colors.sh} "$@"
SH
    chmod +x "$out/bin/jeebis-theme-colors"
    ${lib.optionalString (native && legacy) ''
      ${lib.concatMapStringsSep "\n" (name: ''
        cat > "$out/bin/${name}" <<SH
#!${pkgs.runtimeShell}
exec "$out/bin/jeebis-desktop" legacy ${lib.escapeShellArg name} "\$@"
SH
        chmod +x "$out/bin/${name}"
      '') aliases}
    ''}
  '';
  personalHelpers = pkgs.runCommand "jeebis-personal-desktop-helpers" { nativeBuildInputs = [ pkgs.bash appPkgs.python3 ]; } ''
    mkdir -p "$out"
    cp ${coreSource}/helpers/* "$out/"
    chmod +wx "$out/"*
    substituteInPlace "$out/jeebis-helix-reload" --replace-fail '@pkill@' '${pkgs.procps}/bin/pkill'
    patchShebangs "$out"
  '';
  # Monitor setup stays local. Personal look-and-feel is managed from files/hypr.
  hyprFiles = builtins.filter (path: !(builtins.elem (builtins.baseNameOf path) [ "monitors.lua" ])) (lib.filesystem.listFilesRecursive ../files/hypr);
  relative = base: path: lib.removePrefix ((toString base) + "/") (toString path);
  fileLinks = builtins.listToAttrs (map (path: {
    name = "hypr/${relative ../files/hypr path}";
    value.source = if builtins.baseNameOf path == "bindings.lua" then
      pkgs.writeText "jeebis-bindings.lua" (builtins.replaceStrings
        [ ''"Ruixen App Launcher", desktop.command("shell", "ruixen.notch", "toggleLauncher")''
          ''"Ruixen Settings", desktop.command("shell", "shell", "toggle", "ruixen.launcher", '{"extension":"settings"}')''
          ''"Toggle notch auto-hide", desktop.command("shell", "jeebis.bar", "toggleNotch")''
          ''"Toggle fixed full bar", desktop.command("shell", "jeebis.bar", "toggleFixedBar")''
          ''"Toggle fixed notch", desktop.command("shell", "jeebis.bar", "toggleFixedNotch")'' ]
        [ ''"Tide App Launcher", desktop.command("shell", "tide", "toggleApplicationLauncher")''
          ''"Tide Settings", desktop.command("settings")''
          ''"Toggle Tide Island", desktop.command("shell", "island", "toggle")''
          ''"Show Tide Island", desktop.command("shell", "island", "show")''
          ''"Hide Tide Island", desktop.command("shell", "island", "hide")'' ]
        (builtins.readFile path))
      else if builtins.baseNameOf path == "app-bindings.lua" then
        pkgs.writeText "jeebis-app-bindings.lua" (builtins.replaceStrings
          [ ''"jeebis-terminal", "rio"''
            ''app("Codex (TUIOS)", "jeebis-codex-tuios", "org.omarchy.codex")'' ]
          [ ''"jeebis-terminal", "com.mitchellh.ghostty"''
            ''app("Herdr App", "jeebis-agents", "herdr-app")'' ]
          (builtins.readFile path))
      else path;
  }) hyprFiles);
in
{
  options.jeebis.desktop = {
    compositor = lib.mkOption { type = lib.types.enum [ "hyprland" "niri" ]; default = "hyprland"; description = "Session compositor; Niri is selected by nixosModules.niri during migration."; };
    backend = lib.mkOption { type = lib.types.enum [ "omarchy" "nixos" ]; description = "Host implementation, selected by the flake output."; };
    themeDirectory = lib.mkOption { type = lib.types.str; readOnly = true; default = themeDir; };
    command = lib.mkOption { type = lib.types.str; readOnly = true; default = "${package}/bin/jeebis-desktop"; };
  };
  config = {
    home.packages = [ package tide appPkgs.mpvpaper appPkgs.swayidle appPkgs.fuzzel appPkgs.cava appPkgs.fastfetch ];
    xdg.dataFile."jeebis-desktop/backgrounds".source = coreSource + /backgrounds;
    xdg.configFile = lib.optionalAttrs (cfg.compositor == "hyprland") fileLinks // {
      "jeebis/desktop.lua" = lib.mkIf legacy { text = ''
        local M = {}
        local function quote(s) return o.shell_quote(s) end
        function M.command(...)
          local argv = { ${builtins.toJSON cfg.command}, ... }
          for i, value in ipairs(argv) do argv[i] = quote(value) end
          return table.concat(argv, " ")
        end
        function M.bootstrap() dofile(${builtins.toJSON (if native then "${runtime}/default/hypr/bootstrap.lua" else "/usr/share/omarchy/default/hypr/bootstrap.lua")}) end
        function M.defaults()
          require("default.hypr.omarchy")
          ${lib.optionalString native ''hl.config({ input = { kb_layout = "jp", kb_model = "jp106" } })''}
        end
        function M.toggles() require("default.hypr.toggles") end
        function M.bind(...) return o.bind(...) end
        return M
      ''; };
      "gh-dash/config.yml".source = config.lib.file.mkOutOfStoreSymlink "${themeDir}/gh-dash.yml";
      "jeebis/motion.lua".source = coreSource + /motion.lua;
      "jeebis/curvature.lua".source = coreSource + /curvature.lua;
      "tide-island/userconfig.json".text = builtins.toJSON {
        iconFontFamily = "HackGen35 Console NF";
        wallpaperLibraryPath = "${config.xdg.dataHome}/jeebis-desktop/backgrounds";
        wallpaperPath = "${config.xdg.stateHome}/${if native then "jeebis-desktop" else "omarchy"}/current/home-background";
        wallpaperCustomCommandEnabled = true;
        wallpaperCustomCommand = "${package}/bin/jeebis-desktop wallpaper set \"$1\"";
        wallpaperPywalEnabled = false;
      };
      "jeebis/display-rotation.json".source = coreSource + /display-rotation.json;

    }
    // lib.optionalAttrs (!native) (presetFiles // {
      "omarchy/themed/palette.lua.tpl".source = templates + /palette.lua.tpl;
      "omarchy/themed/preview.tmTheme.tpl".source = templates + /preview.tmTheme.tpl;
      "omarchy/themed/yazi.toml.tpl".source = templates + /yazi.toml.tpl;
      "omarchy/themed/ghostty.conf.tpl".source = templates + /ghostty.conf.tpl;
      "omarchy/themed/rio.toml.tpl".source = templates + /rio.toml.tpl;
      "omarchy/themed/gh-dash.yml.tpl".source = templates + /gh-dash.yml.tpl;
      "omarchy/themed/helix.toml.tpl".source = templates + /helix.toml.tpl;
      "omarchy/hooks/theme-set.d/refresh-helix.hook" = { source = ../files/omarchy/hooks/theme-set.d/refresh-helix.hook; executable = true; };
      "omarchy/hooks/theme-set.d/refresh-ghostty.hook" = { text = "#!${pkgs.runtimeShell}\nexec ${config.home.profileDirectory}/bin/jeebis-ghostty-reload\n"; executable = true; };
      "omarchy/hooks/theme-set.d/refresh-rio.hook" = { source = ../files/omarchy/hooks/theme-set.d/refresh-rio.hook; executable = true; };
      "omarchy/hooks/theme-set.d/refresh-bat.hook" = { source = ../files/omarchy/hooks/theme-set.d/refresh-bat.hook; executable = true; };
    });
    home.file.".local/bin/jeebis-helix-reload" = { source = personalHelpers + /jeebis-helix-reload; executable = true; };
    home.file.".local/bin/jeebis-tuios" = lib.mkIf legacy { source = personalHelpers + /jeebis-tuios; executable = true; };
    home.file.".local/bin/jeebis-tuios-select-tab" = lib.mkIf legacy { source = personalHelpers + /jeebis-tuios-select-tab; executable = true; };
    home.file.".local/bin/jeebis-tuios-edit-config" = lib.mkIf legacy { source = personalHelpers + /jeebis-tuios-edit-config; executable = true; };
    home.file.".local/bin/jeebis-tuios-worktree" = lib.mkIf legacy { source = personalHelpers + /jeebis-tuios-worktree; executable = true; };
    home.file.".local/bin/jeebis-codex-sidebar" = lib.mkIf legacy { source = personalHelpers + /jeebis-codex-sidebar; executable = true; };
    home.file.".local/bin/jeebis-gh-dash-tuios" = lib.mkIf legacy { source = personalHelpers + /jeebis-gh-dash-tuios; executable = true; };
    home.file.".local/bin/jeebis-codex-tuios" = lib.mkIf legacy { source = personalHelpers + /jeebis-codex-tuios; executable = true; };
    home.file.".local/bin/jeebis-theme-cycle" = { text = "#!${pkgs.runtimeShell}\nexec ${cfg.command} theme cycle\n"; executable = true; };
    home.activation = {
      initializeHyprMonitors = lib.mkIf (cfg.compositor == "hyprland") (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run mkdir -p "$HOME/.config/hypr"
      if [ ! -e "$HOME/.config/hypr/monitors.lua" ]; then
        run install -m644 ${../files/hypr/monitors.lua} "$HOME/.config/hypr/monitors.lua"
      fi
    '');
      refreshDesktopAppearance = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ -f "${themeDir}/colors.toml" ]; then
          run ${package}/bin/jeebis-desktop theme refresh
        fi
      '';
    } // lib.optionalAttrs native {
      initializeDesktopTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${package}/bin/jeebis-desktop theme init
      '';
    };
    systemd.user.services = {
      jeebis-display-rotation = lib.mkIf (cfg.compositor == "hyprland") {
        Unit = { Description = "Automatic display rotation, including the locked session"; After = [ "wayland-session-waitenv.service" ]; PartOf = [ "graphical-session.target" ]; };
        Service = { ExecStart = "${rotation}/bin/jeebis-display-rotation session ${config.xdg.configHome}/jeebis/display-rotation.json"; Restart = "on-failure"; RestartSec = 3; };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      tide-island = {
        Unit = { Description = "Tide Island desktop shell"; After = [ "graphical-session-pre.target" "wayland-session-waitenv.service" ]; PartOf = [ "graphical-session.target" ]; Conflicts = [ "jeebis-desktop.service" "omarchy-shell.service" ]; };
        Service = { ExecStart = "${tide}/bin/tide-island"; Restart = "on-failure"; RestartSec = 3; };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      jeebis-wallpaper = {
        Unit = {
          Description = "Personal desktop wallpaper (images, GIF and video)";
          After = [ "wayland-session-waitenv.service" ]; PartOf = [ "graphical-session.target" ];
          ConditionPathExists = "${config.xdg.stateHome}/${if native then "jeebis-desktop" else "omarchy"}/current/home-background";
        };
        Service = {
          ExecStart = "${appPkgs.mpvpaper}/bin/mpvpaper -o 'no-audio loop-file=inf image-display-duration=inf' '*' ${config.xdg.stateHome}/${if native then "jeebis-desktop" else "omarchy"}/current/home-background";
          Restart = "on-failure"; RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      jeebis-idle = {
        Unit = { Description = "Lock idle session and before sleep"; After = [ "tide-island.service" ]; PartOf = [ "graphical-session.target" ]; };
        Service = {
          ExecStart = "${appPkgs.swayidle}/bin/swayidle -w timeout 600 '${package}/bin/jeebis-desktop lock' before-sleep '${package}/bin/jeebis-desktop lock'";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
