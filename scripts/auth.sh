#!/usr/bin/env bash
set -euo pipefail
need() { command -v "$1" >/dev/null || { echo "$1 がありません。先に just switch で導入してください。" >&2; exit 1; }; }
op_cli() {
  if [[ -x /run/wrappers/bin/op ]]; then /run/wrappers/bin/op "$@"; else op "$@"; fi
}
github_token() {
  local reference
  reference=$(git config --global --get dotfiles.github-token-reference) || { echo '先に just git-auth を実行してください。' >&2; return 1; }
  [[ $reference == op://* ]] || return 1
  op_cli read "$reference"
}
rclone_auth() {
  local remote=$1 provider config remotes
  case $remote in gdrive) provider=drive ;; onedrive) provider=onedrive ;; *) echo 'remote は gdrive / onedrive / all です。' >&2; return 2 ;; esac
  config=${XDG_CONFIG_HOME:-$HOME/.config}/rclone/rclone.conf
  mkdir -p "$(dirname "$config")"
  umask 077
  remotes=$(rclone --config "$config" listremotes) || return
  if grep -Fxq "$remote:" <<< "$remotes"; then
    rclone --config "$config" config reconnect "$remote:"
  else
    echo "新しい remote を作成してください: 名前=$remote / 種類=$provider" >&2
    rclone --config "$config" config
    rclone --config "$config" listremotes | grep -Fxq "$remote:" || {
      echo "$remote が未作成です。もう一度 rclone-auth を実行してください。" >&2
      return 1
    }
  fi
  chmod 600 "$config"
}
main() {
  local action=${1:-status} reference token
  shift || true
  case $action in
    op)
      need op
      echo '1Password アプリにログインし、設定 > Developer > CLI 連携を有効にしてください。' >&2
      if command -v 1password >/dev/null; then
        (1password >/dev/null 2>&1 &)
      fi
      op_cli whoami
      ;;
    git)
      need op; need git; need gh; need git-credential-op
      reference=${1:-}
      if [[ -z $reference ]]; then
        read -r -p 'GitHub PAT の参照 (op://Vault/Item/field): ' reference
      fi
      [[ $reference == op://* ]] || { echo 'トークン本体ではなく op:// の参照を指定してください。' >&2; return 2; }
      # Validate before changing Git settings. Do not persist the token in gh.
      token=$(op_cli read "$reference")
      [[ -n $token ]] || return 1
      GH_TOKEN=$token gh api user --jq .login
      git config --global dotfiles.github-token-reference "$reference"
      git config --global --replace-all credential.https://github.com.helper ''
      git config --global --add credential.https://github.com.helper '!git-credential-op'
      echo 'GitHub HTTPS は 1Password から取得します。gh は just gh で実行できます。'
      ;;
    gh)
      need gh
      token=$(github_token)
      [[ -n $token ]] || return 1
      GH_TOKEN=$token gh "$@"
      ;;
    rclone)
      need rclone
      if [[ ${1:-all} == all ]]; then rclone_auth gdrive; rclone_auth onedrive; else rclone_auth "$1"; fi
      ;;
    status)
      if command -v op >/dev/null; then op_cli whoami || true; fi
      if git config --global --get dotfiles.github-token-reference >/dev/null; then
        echo 'GitHub: 1Password reference configured (just gh auth status で確認)'
      elif command -v gh >/dev/null; then gh auth status; fi
      if command -v rclone >/dev/null; then
        rclone --config "${XDG_CONFIG_HOME:-$HOME/.config}/rclone/rclone.conf" listremotes
      fi
      ;;
    *) echo '使い方: auth.sh {op|git [op://reference]|gh ...|rclone [gdrive|onedrive|all]|status}' >&2; return 2 ;;
  esac
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
