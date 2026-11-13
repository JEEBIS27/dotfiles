{ config, lib, pkgs, ... }:
let
  recordedFish = pkgs.writeShellApplication {
    name = "jeebis-recorded-fish";
    runtimeInputs = [ pkgs.util-linux pkgs.coreutils ];
    text = ''
      # tmux sets SHELL to default-shell, which is this wrapper. script uses
      # SHELL to launch --command: point it at fish to prevent recursion.
      export SHELL="${config.jeebis.shell.package}/bin/fish"
      # tmux also invokes default-shell -c COMMAND for tool panes/popups.
      if (( $# > 0 )); then
        exec "$SHELL" "$@"
      fi
      umask 077
      capture_dir=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/jeebis-output.XXXXXXXX")
      trap 'rm -rf -- "$capture_dir"' EXIT
      export JEEBIS_OUTPUT_LOG="$capture_dir/output"
      JEEBIS_OUTPUT_TOKEN=$(cat /proc/sys/kernel/random/uuid)
      export JEEBIS_OUTPUT_TOKEN
      script --quiet --flush --return --log-out "$JEEBIS_OUTPUT_LOG" \
        --command 'exec ${config.jeebis.shell.package}/bin/fish'
    '';
  };
  outputPython = pkgs.python3.withPackages (ps: [ ps.pyte ]);
  launcher = pkgs.writeShellApplication {
    name = "jeebis-terminal";
    runtimeInputs = [ pkgs.ghostty ];
    text = builtins.readFile ../files/desktop/helpers/jeebis-terminal;
  };
in {
  options.jeebis.terminal.command = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = "${launcher}/bin/jeebis-terminal";
    description = "Compositor-independent terminal launcher.";
  };
  config = {
    home.packages = [ launcher recordedFish (pkgs.writeShellScriptBin "jeebis-last-output"
      "exec ${outputPython}/bin/python3 ${../files/desktop/helpers/jeebis-last-output.py} \"$@\"") (pkgs.writeShellApplication {
      name = "jeebis-ghostty-reload";
      runtimeInputs = [ pkgs.python3 ];
      text = "exec python3 ${../packages/desktop/reload-ghostty.py}";
    }) ];
    home.sessionVariables.TERMINAL = "jeebis-terminal";
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      settings = {
        command = "${recordedFish}/bin/jeebis-recorded-fish";
        font-family = "HackGen35 Console NF";
        font-size = 14;
        # Rio used weight 700 for regular text too.
        font-style = "Bold";
        font-style-bold = "Bold";
        font-style-italic = "Bold";
        font-style-bold-italic = "Bold";
        window-decoration = false;
        window-padding-x = 14;
        window-padding-y = 14;
        cursor-style = "block";
        cursor-style-blink = false;
        shell-integration-features = "no-cursor";
        custom-shader = "${config.xdg.configHome}/ghostty/cursor-trail.glsl";
        custom-shader-animation = true;
        mouse-hide-while-typing = true;
        config-file = "?${config.jeebis.desktop.themeDirectory}/ghostty.conf";
        # Explicitly own only the emulator layer. Ghostty defaults consume
        # Ctrl+Enter, Ctrl+Tab, Ctrl+numbers and Shift movement before TUIs.
        keybind = import ../files/ghostty/keybindings.nix;
      };
    };
    xdg.configFile."ghostty/cursor-trail.glsl".source = ../files/ghostty/cursor-trail.glsl;
    xdg.configFile."xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
    # Persistence is opt-in: plain terminal/app launches never attach a mux.
    programs.tmux = {
      enable = true;
      terminal = "tmux-256color";
      escapeTime = 0;
      historyLimit = 50000;
      mouse = true;
      shell = "${recordedFish}/bin/jeebis-recorded-fish";
      extraConfig = builtins.replaceStrings
        [ "@fish@" ] [ "${config.jeebis.shell.package}/bin/fish" ]
        (builtins.readFile ../files/tmux/tmux.conf)
        + "\n" + import ../files/tmux/copy-keys.nix { inherit lib; };
    };
  };
}
