#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  theme)
    exec omarchy menu summon style.theme
    ;;
  chatgpt)
    exec omarchy-launch-or-focus chatgpt 'uwsm-app -- chatgpt'
    ;;
  codex)
    exec omarchy-launch-or-focus '^org\.omarchy\.codex$' 'omarchy-launch-tui --app-id=org.omarchy.codex codex'
    ;;
  overview)
    if [[ ! -f "$HOME/.config/omarchy/plugins/jeebis.overview/manifest.json" ]]; then
      notify-send -a omarchy-action 'Overviewは未導入です' 'プレビュー一覧プラグインの導入承認が必要です。'
      exit 1
    fi
    exec omarchy-shell shell summon jeebis.overview '{}'
    ;;
  calendar)
    exec omarchy-launch-or-focus 'calendar.google.com|Google Calendar' 'omarchy-launch-webapp https://calendar.google.com/calendar/u/0/r'
    ;;
  *)
    echo 'Usage: jeebis-bar-action {theme|chatgpt|codex|overview|calendar}' >&2
    exit 2
    ;;
esac
