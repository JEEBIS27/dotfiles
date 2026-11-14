# Git credential protocol: never persist tokens; answer github.com only.
set -euo pipefail
[[ ${1:-} == get ]] || exit 0
protocol='' host=''
while IFS='=' read -r key value && [[ -n $key ]]; do
  case $key in protocol) protocol=$value ;; host) host=$value ;; esac
done
[[ $protocol == https && $host == github.com ]] || exit 0
reference=$(git config --global --get dotfiles.github-token-reference)
[[ $reference == op://* ]] || { echo 'Run just git-auth first.' >&2; exit 1; }
# Use the NixOS setgid wrapper when present; the store binary cannot integrate.
op_command=op
[[ ! -x /run/wrappers/bin/op ]] || op_command=/run/wrappers/bin/op
token=$("$op_command" read "$reference")
[[ -n $token && $token != *$'\n'* && $token != *$'\r'* ]] || exit 1
printf 'username=x-access-token\npassword=%s\n\n' "$token"
