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
      modules = [ ./configuration.nix dotfiles.nixosModules.personal ];
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
# Refresh only the local checkout snapshot; its own flake.lock keeps packages pinned.
sudo nix --extra-experimental-features 'nix-command flakes' \
  flake update dotfiles --flake path:/etc/nixos
# nixos-rebuild-ng accepts generic Nix options rather than Nix CLI feature flags.
sudo nixos-rebuild "$action" --flake path:/etc/nixos#jeebis \
  --option experimental-features 'nix-command flakes'
