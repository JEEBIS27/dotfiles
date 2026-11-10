{ appPkgs, config, lib, pkgs, ... }:
let
  app = import ../packages/chatgpt.nix { inherit pkgs; };
  legacy = config.jeebis.desktop.compositor == "hyprland";
  newWindow = pkgs.writeShellApplication {
    name = "jeebis-chatgpt-new-window";
    runtimeInputs = [ app ] ++ lib.optionals legacy [
      appPkgs.hyprland appPkgs.uwsm pkgs.libnotify pkgs.python3
    ];
    text = if legacy then ''
      exec ${pkgs.python3}/bin/python3 ${../files/desktop/helpers/jeebis-chatgpt-new-window} "$@"
    '' else ''
      # Compatibility command name. Niri uses the app's own activation behavior;
      # no unverified CLI flag or synthetic Hyprland shortcut is sent.
      exec ${app}/bin/chatgpt "$@"
    '';
  };
in {
  home.packages = [ app newWindow ];
  # Register only the app's callback scheme; Helium remains the web browser.
  xdg.mimeApps.defaultApplications."x-scheme-handler/codex" = [ "chatgpt.desktop" ];
  # Login tokens, chats, caches and app-local preferences remain local.
}
