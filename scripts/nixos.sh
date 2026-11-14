#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ ! -e /etc/NIXOS ]]; then
  echo 'NixOSの移行先PCで実行してください。' >&2
  exit 1
fi
if [[ $(id -un) != jeebis ]]; then
  echo 'jeebisとして実行してください。' >&2
  exit 1
fi
mode=${1:-build}
case "$mode" in
  setup)
    if sudo test -e /etc/nixos/flake.nix; then
      echo '/etc/nixos/flake.nix は既にあります。既存flakeへの手動統合が必要です。' >&2
      exit 1
    fi
    sudo test -f /etc/nixos/configuration.nix
    sudo cp -a /etc/nixos "/etc/nixos.backup-$(date +%Y%m%d-%H%M%S)"
    # JSON quoting is also valid for Nix strings; reject Nix interpolation.
    if [[ $repo == *'${'* ]]; then
      echo 'リポジトリのパスにNix補間構文は使用できません。' >&2
      exit 1
    fi
    repo_url=$(JEEBIS_DOTFILES_ROOT="$repo" nix --extra-experimental-features 'nix-command flakes' \
      eval --impure --raw --expr 'builtins.toJSON ("path:" + builtins.getEnv "JEEBIS_DOTFILES_ROOT")')
    sudo tee /etc/nixos/flake.nix >/dev/null <<NIX
{
  inputs.dotfiles.url = $repo_url;
  outputs = { dotfiles, ... }: {
    nixosConfigurations.jeebis = dotfiles.inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix dotfiles.nixosModules.personal ]
        ++ (if builtins.pathExists ./jeebis-boot.nix then [ ./jeebis-boot.nix ] else []);
    };
  };
}
NIX
    action=build
    ;;
  build) action=build ;;
  switch) action=switch ;;
  sync)
    git -C "$repo" pull --ff-only
    action=switch
    ;;
  *) echo '使い方: bash scripts/nixos.sh {setup|build|switch|sync}' >&2; exit 2 ;;
esac
# Resolve private inputs as the logged-in user, whose Git helper can access op.
# Preserve /etc/nixos ownership: build from a private writable snapshot instead.
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cp -r /etc/nixos/. "$work/"
chmod -R u+w "$work"
nix --extra-experimental-features 'nix-command flakes' \
  flake update dotfiles --flake "path:$work"
# Elevate only activation/profile operations, not evaluation or source fetching.
nixos-rebuild "$action" --sudo --flake "path:$work#jeebis" \
  --option experimental-features 'nix-command flakes'
# Keep the integration lock for subsequent invocations after a successful build.
sudo install -m 644 "$work/flake.lock" /etc/nixos/flake.lock
