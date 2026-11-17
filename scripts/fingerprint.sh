#!/usr/bin/env bash
set -euo pipefail

fail() { echo "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || fail "$1 がありません。先に just switch で指紋認証を導入してください。"; }

action=${1:-enroll}
finger=${2:-}
user=${USER:?USER is not set}
[[ $EUID -ne 0 ]] || fail 'sudo を付けず、普段のユーザーで実行してください。'

case $action in
  enroll|add)
    need fprintd-enroll
    if [[ -n $finger ]]; then
      case $finger in
        left-thumb|left-index-finger|left-middle-finger|left-ring-finger|left-little-finger|\
        right-thumb|right-index-finger|right-middle-finger|right-ring-finger|right-little-finger) ;;
        *) fail '指は right-index-finger / left-thumb などを指定してください。' ;;
      esac
      exec fprintd-enroll -f "$finger" "$user"
    fi
    exec fprintd-enroll "$user"
    ;;
  list)
    need fprintd-list
    exec fprintd-list "$user"
    ;;
  verify|test)
    need fprintd-verify
    if [[ -n $finger ]]; then exec fprintd-verify -f "$finger" "$user"; fi
    exec fprintd-verify "$user"
    ;;
  delete|remove)
    need fprintd-delete
    read -r -p "$user の登録済み指紋をすべて削除しますか？ [y/N] " answer
    [[ $answer == y || $answer == Y ]] || { echo '中止しました。'; exit 0; }
    exec fprintd-delete "$user"
    ;;
  *)
    fail '使い方: just fingerprint [enroll|list|verify|delete] [right-index-finger など]'
    ;;
esac
