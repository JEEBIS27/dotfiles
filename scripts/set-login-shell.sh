#!/usr/bin/env bash
set -euo pipefail
# Run after Home Manager activation on the Omarchy host.
[[ $(id -un) == jeebis && $HOME == /home/jeebis ]] || {
  echo 'Omarchyのjeebisユーザーで実行してください。' >&2; exit 1;
}
fish_shell="$HOME/.nix-profile/bin/fish"
[[ -x $fish_shell ]] || { echo '先にHome Managerを適用してください。' >&2; exit 1; }
if [[ $(getent passwd jeebis | cut -d: -f7) == "$fish_shell" ]]; then
  echo 'ログインシェルは既にfishです。'; exit 0
fi
sudo sh -c 'grep -qxF "$1" /etc/shells || printf "%s\n" "$1" >> /etc/shells' sh "$fish_shell"
sudo usermod --shell "$fish_shell" jeebis
printf 'ログインシェルを%sへ変更しました。新しいログインから有効です。\n' "$fish_shell"
