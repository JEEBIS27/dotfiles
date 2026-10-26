#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

fail() { printf '%s\n' "$*" >&2; return 1; }

is_nixos() { [[ -e /etc/NIXOS ]]; }
is_android() {
  [[ ${HOME:-} == /data/data/com.termux.nix/files/home ]] && command -v nix-on-droid >/dev/null 2>&1
}
is_omarchy() { [[ -d /usr/share/omarchy ]]; }

detect_host() {
  # Check Android before desktop markers; never select a PC profile there.
  if is_android; then
    printf '%s\n' android
  elif is_nixos; then
    printf '%s\n' nixos
  elif is_omarchy; then
    printf '%s\n' omarchy
  else
    fail '対応環境を判定できません。Omarchy / NixOS / Nix-on-Droid内で実行してください。'
  fi
}

require_host() {
  local host=$1
  if [[ $host == android ]]; then
    [[ $(uname -m) == aarch64 ]] || fail 'Android構成はaarch64用です。'
  else
    [[ $(uname -m) == x86_64 && $(id -un) == jeebis && ${HOME:-} == /home/jeebis && $repo == /home/jeebis/Git/home-manager ]] ||
      fail 'PC構成はx86_64のjeebis用です。/home/jeebis/Git/home-managerに配置してください。'
  fi
}

nixos_flake_exists() { [[ -e /etc/nixos/flake.nix ]]; }
run_nixos() { bash "$repo/scripts/nixos.sh" "$1"; }

apply() {
  local host=$1 action=$2
  case $host in
    nixos)
      if ! nixos_flake_exists; then
        # setup already builds. If it fails, never proceed to switch.
        run_nixos setup
        if [[ $action == build ]]; then return; fi
      fi
      run_nixos "$action"
      ;;
    omarchy)
      # Use the locked Home Manager CLI even on a fresh Nix installation.
      nix run "path:$repo#home-manager" -- "$action" --flake "path:$repo#jeebis@omarchy"
      ;;
    android)
      if [[ $action == build ]]; then
        nix build "path:$repo#nixOnDroidConfigurations.galaxy-tab-s11.activationPackage" --no-link
      else
        nix-on-droid switch --flake "path:$repo#galaxy-tab-s11"
      fi
      ;;
  esac
}

main() {
  local action=${1:-switch} host
  if (( $# > 1 )); then fail '使い方: bash scripts/manage.sh {switch|build|sync|host|setup}'; return 2; fi
  case $action in
    switch|build|sync|host|setup) ;;
    *) fail '使い方: bash scripts/manage.sh {switch|build|sync|host|setup}'; return 2 ;;
  esac
  host=$(detect_host)
  if [[ $action == host ]]; then printf '%s\n' "$host"; return; fi
  require_host "$host"
  # Also enable flakes in child commands such as home-manager/nix-on-droid.
  export NIX_CONFIG="${NIX_CONFIG-}"$'\n''extra-experimental-features = nix-command flakes'
  if [[ $action == setup ]]; then
    [[ $host == nixos ]] || { fail 'setupはNixOS専用です。通常はjust build / just switchを使ってください。'; return 1; }
    run_nixos setup
    return
  fi
  if [[ $action == sync ]]; then
    git -C "$repo" pull --ff-only
    action=switch
  fi
  apply "$host" "$action"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
