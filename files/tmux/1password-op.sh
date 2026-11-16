# Desktop-app integration: authentication belongs to op, with no token file.
op::verify_version() { op --version >/dev/null; }
op::verify_session() { op whoami --account="$(options::op_account)" >/dev/null; }
op::get_all_items() {
  local -a args=(--account="$(options::op_account)" --categories=LOGIN,PASSWORD --format=json)
  local vault="$(options::op_valut)" tags="$(options::op_filter_tags)"
  [[ -z "$vault" ]] || args+=(--vault="$vault")
  [[ -z "$tags" ]] || args+=(--tags="$tags")
  op item list "${args[@]}" | jq -r '.[] | [.title, .id] | join(",")'
}
op::get_item_password() {
  op item get "$1" --account="$(options::op_account)" --fields type=concealed --format=json |
    jq -r '[.] | flatten | map(select(.purpose == "PASSWORD")) | .[0].value'
}
op::get_item_totp() { op item get "$1" --account="$(options::op_account)" --otp; }
