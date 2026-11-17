# Desktop-app integration: authentication belongs to op, with no token file.
op::run() {
  # NixOS's setgid wrapper is required for desktop-app integration.
  if [[ -x /run/wrappers/bin/op ]]; then
    /run/wrappers/bin/op "$@"
  else
    op "$@"
  fi
}
op::cli() {
  local account="$(options::op_account)"
  local -a args=("$@")
  [[ -z "$account" ]] || args+=(--account="$account")
  op::run "${args[@]}"
}
op::failure() {
  printf '\n1Password: %s\n' "$1" >&2
  if [[ -t 0 ]]; then
    read -r -p 'Enterでこのペインを閉じます。' || true
  fi
}
op::verify_version() {
  op::cli --version >/dev/null || {
    op::failure 'CLIを起動できませんでした。上のエラーを確認してください。'
    return 1
  }
}
op::verify_session() {
  # whoami only checks state; signin initiates desktop authentication.
  if ! op::cli signin >/dev/null; then
    op::failure 'サインインできませんでした。アプリのCLI連携とロック状態を確認してください。'
    return 1
  fi
  op::cli whoami >/dev/null || {
    op::failure 'サインイン後の状態を確認できませんでした。'
    return 1
  }
}
op::get_all_items() {
  local -a args=(--categories=LOGIN,PASSWORD --format=json)
  local vault="$(options::op_valut)" tags="$(options::op_filter_tags)"
  [[ -z "$vault" ]] || args+=(--vault="$vault")
  [[ -z "$tags" ]] || args+=(--tags="$tags")
  (set -o pipefail; op::cli item list "${args[@]}" | jq -r '.[] | [.title, .id] | join(",")')
}
op::get_item_password() {
  (set -o pipefail
   op::cli item get "$1" --fields type=concealed --format=json |
     jq -er '[.] | flatten | map(select(.purpose == "PASSWORD")) | .[0].value')
}
op::get_item_totp() { op::cli item get "$1" --otp; }
