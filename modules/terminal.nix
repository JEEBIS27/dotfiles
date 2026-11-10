{ config, lib, pkgs, ... }:
let
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
    home.packages = [ launcher (pkgs.writeShellApplication {
      name = "jeebis-ghostty-reload";
      runtimeInputs = [ pkgs.python3 ];
      text = "exec python3 ${../packages/desktop/reload-ghostty.py}";
    }) ];
    home.sessionVariables.TERMINAL = "jeebis-terminal";
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      settings = {
        command = "${config.jeebis.shell.package}/bin/fish";
        font-family = "HackGen35 Console NF";
        font-size = 14;
        window-decoration = false;
        window-padding-x = 14;
        window-padding-y = 14;
        cursor-style = "block";
        cursor-style-blink = false;
        mouse-hide-while-typing = true;
        config-file = "?${config.jeebis.desktop.themeDirectory}/ghostty.conf";
        keybind = [
          "ctrl+insert=copy_to_clipboard" "shift+insert=paste_from_clipboard"
          "ctrl+alt+equal=increase_font_size:1" "ctrl+alt+minus=decrease_font_size:1"
          "ctrl+alt+0=reset_font_size"
        ];
      };
    };
    xdg.configFile."xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
    # Persistence is opt-in: plain terminal/app launches never attach a mux.
    programs.tmux = {
      enable = true;
      terminal = "tmux-256color";
      escapeTime = 0;
      historyLimit = 50000;
      mouse = true;
      shell = "${config.jeebis.shell.package}/bin/fish";
    };
  };
}
