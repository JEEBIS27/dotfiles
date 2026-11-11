{ config, pkgs }:
let
  terminal = config.jeebis.terminal.command;
  spotify = import ../../packages/spotify.nix { inherit pkgs; };
  helium = import ../../packages/helium.nix { inherit pkgs; };
  herdr = import ../../packages/herdr-app.nix { inherit pkgs; };
  chatgpt = import ../../packages/chatgpt.nix { inherit pkgs; };
  tui = key: name: id: argv: {
    inherit key name;
    argv = [ terminal "--app-id=org.jeebis.${id}" "--" ] ++ argv;
    appIds = [ "org.jeebis.${id}" ];
  };
  web = key: name: id: url: {
    inherit key name url;
    argv = [ "${helium}/bin/helium" "--new-window" "--class=org.jeebis.web.${id}" "--app=${url}" ];
    appIds = [ "org.jeebis.web.${id}" ];
  };
in {
  terminal = { key = "Return"; name = "Ghostty"; terminal = true; argv = [ terminal "--app-id=org.jeebis.terminal" ]; appIds = [ "org.jeebis.terminal" ]; };
  terminal-tmux = {
    key = null;
    name = "Ghostty + tmux";
    terminal = true;
    argv = [ terminal "--app-id=org.jeebis.tmux" "--" "${pkgs.tmux}/bin/tmux" "new-session" ];
    appIds = [ "org.jeebis.tmux" ];
  };
  browser = { key = "Space"; name = "Browser"; argv = [ "${helium}/bin/helium" "--new-window" ]; appIds = [ "helium" "chromium" "chromium-browser" ]; };
  activity = tui "A" "Activity" "btop" [ "${pkgs.btop}/bin/btop" ];
  slides = web "B" "Google Slides" "slides" "https://docs.google.com/presentation";
  chatgpt = { key = "C"; name = "ChatGPT"; argv = [ "${chatgpt}/bin/chatgpt" ]; appIds = [ "chatgpt" "ChatGPT" ]; };
  agents = { key = "D"; name = "Herdr App"; argv = [ "${herdr}/bin/herdr-app" ]; appIds = [ "herdr-app" ]; };
  sheets = web "E" "Google Sheets" "sheets" "https://docs.google.com/spreadsheets/";
  files = { key = "F"; name = "Files"; argv = [ "${pkgs.nautilus}/bin/nautilus" "--new-window" ]; appIds = [ "org.gnome.Nautilus" ]; };
  github = tui "G" "GitHub" "github" [ "${pkgs.gh-dash}/bin/gh-dash" ];
  slack = { key = "I"; name = "Slack"; argv = [ "${pkgs.slack}/bin/slack" ]; appIds = [ "Slack" "slack" ]; };
  spotify = { key = "M"; name = "Spotify"; argv = [ "${spotify}/bin/spotify" ]; appIds = [ "spotify" ]; };
  editor = tui "N" "Helix" "editor" [ "${config.programs.helix.package}/bin/hx" ];
  obsidian = { key = "O"; name = "Obsidian"; argv = [ "${pkgs.obsidian}/bin/obsidian" ]; appIds = [ "obsidian" "md.obsidian.Obsidian" ]; };
  calendar = web "Q" "Google Calendar" "calendar" "https://calendar.google.com/calendar";
  teams = web "R" "Teams" "teams" "https://teams.cloud.microsoft/";
  youtube = web "U" "YouTube" "youtube" "https://www.youtube.com/";
  docs = web "W" "Google Docs" "docs" "https://docs.google.com/document";
  localsend = { key = "X"; name = "LocalSend"; argv = [ "${pkgs.localsend}/bin/localsend" ]; appIds = [ "localsend" "localsend_app" ]; };
  yazi = tui "Y" "Yazi" "yazi" [ "${config.jeebis.shell.package}/bin/fish" "-i" "-c" "__jeebis_yazi; exec ${config.jeebis.shell.package}/bin/fish -i" ];
  zathura = { key = "Z"; name = "Zathura"; argv = [ "${pkgs.zathura}/bin/zathura" ]; appIds = [ "org.pwmt.zathura" "Zathura" ]; };
}
