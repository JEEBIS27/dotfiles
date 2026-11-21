{ pkgs }:
pkgs.writeShellApplication {
  name = "jeebis-pane-focus";
  runtimeInputs = [ pkgs.tmux ];
  text = ''exec ${pkgs.python3}/bin/python3 ${../files/ghostty/pane-focus.py} "$@"'';
}
