#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ -e /etc/NIXOS ]] || fail 'このコマンドは移行先のNixOS PC専用です。'
[[ $(id -un) == jeebis ]] || fail 'jeebisとして実行してください。'
mode=${1:-}
case "$mode" in
  prepare)
    systemd-analyze has-tpm2 >/dev/null || fail 'TPM 2.0の対応状況を確認してください。'
    [[ -d /sys/firmware/efi ]] || fail 'UEFI起動が必要です。'
    sudo test -f /etc/nixos/flake.nix || fail '先に既存のNixOS連携flakeを用意してください。'
    original=$(sudo cat /etc/nixos/flake.nix)
    old='modules = [ ./configuration.nix dotfiles.nixosModules.personal ];'
    new='modules = [ ./configuration.nix dotfiles.nixosModules.personal ] ++ (if builtins.pathExists ./jeebis-boot.nix then [ ./jeebis-boot.nix ] else []);'
    if [[ $original == *'builtins.pathExists ./jeebis-boot.nix'* ]]; then
      updated=$original
    elif [[ $original == *"$old"* ]]; then
      updated=${original/"$old"/"$new"}
    else
      fail '既存flakeの形式が異なるため変更せず停止しました。/etc/nixos/flake.nixを確認してください。'
    fi
    temp=$(mktemp -d)
    trap 'rm -rf -- "$temp"' EXIT
    cat > "$temp/jeebis-boot.nix" <<'NIX'
{ ... }: {
  jeebis.boot.tpmUnlock = {
    enable = true;
    rootName = "cryptroot";
  };
}
NIX
    if sudo test -e /etc/nixos/jeebis-boot.nix; then
      sudo cmp -s "$temp/jeebis-boot.nix" /etc/nixos/jeebis-boot.nix ||
        fail '既存のjeebis-boot.nixは上書きしません。内容を確認してください。'
    fi
    # Resolve the tool as the user; never embed credentials or host keys in Nix.
    sbctl_path=$(nix --extra-experimental-features 'nix-command flakes' build \
      --no-link --print-out-paths "path:$repo#sbctl")
    if sudo test -d /var/lib/sbctl/keys; then
      for name in PK KEK db; do
        sudo test -s "/var/lib/sbctl/keys/$name/$name.key" &&
          sudo test -s "/var/lib/sbctl/keys/$name/$name.pem" ||
          fail '既存の署名鍵が不完全です。鍵は上書きせず停止しました。'
      done
    else
      sudo "$sbctl_path/bin/sbctl" create-keys
    fi
    backup="/etc/nixos.before-tpm-$(date +%Y%m%d-%H%M%S)"
    sudo cp -a /etc/nixos "$backup"
    printf '%s\n' "$updated" > "$temp/flake.nix"
    sudo install -m 644 "$temp/flake.nix" /etc/nixos/flake.nix
    sudo install -m 644 "$temp/jeebis-boot.nix" /etc/nixos/jeebis-boot.nix
    printf '準備完了。バックアップ: %s\n' "$backup"
    echo 'まだ起動構成の適用・UEFI鍵登録・LUKS鍵登録はしていません。'
    echo '次は just switch を実行し、成功した結果を確認してください。'
    ;;
  enroll)
    # Read the SecureBoot EFI variable without depending on localized output.
    variables=(/sys/firmware/efi/efivars/SecureBoot-*)
    [[ ${#variables[@]} == 1 && -e ${variables[0]} ]] || fail 'Secure Bootの状態を取得できません。'
    state=$(sudo od -An -tu1 -j4 -N1 "${variables[0]}" | tr -d '[:space:]')
    [[ $state == 1 ]] || fail '先に署名済み構成での起動とSecure Boot有効化を完了してください。'
    [[ $(readlink -f /run/booted-system) == "$(readlink -f /run/current-system)" ]] ||
      fail '構成変更後の再起動が必要です。'
    [[ -e /dev/mapper/cryptroot ]] || fail 'cryptrootが開かれていません。'
    device=$(sudo cryptsetup status cryptroot | awk '$1 == "device:" { print $2 }')
    [[ -b $device ]] || fail '暗号化ルートの実デバイスを取得できません。'
    metadata=$(sudo cryptsetup luksDump --dump-json-metadata "$device")
    if grep -Eq '"type"[[:space:]]*:[[:space:]]*"systemd-tpm2"' <<< "$metadata"; then
      fail '既存のTPM登録があります。上書きせず停止しました。'
    fi
    sudo systemctl start systemd-pcrlock-secureboot-policy.service systemd-pcrlock-secureboot-authority.service
    sudo systemctl start systemd-pcrlock-make-policy.service
    sudo test -s /var/lib/systemd/pcrlock.json || fail 'Measured Boot policyが作成されていません。'
    # Adds one TPM slot. No --wipe-slot: the passphrase/recovery slots survive.
    sudo install -d -m 700 /var/lib/jeebis-nixos-tpm/backup
    header="/var/lib/jeebis-nixos-tpm/backup/luks-header-$(date +%Y%m%d-%H%M%S).img"
    sudo cryptsetup luksHeaderBackup "$device" --header-backup-file "$header"
    sudo chmod 600 "$header"
    sudo systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=no --tpm2-pcrs= \
      --tpm2-pcrlock=/var/lib/systemd/pcrlock.json "$device"
    echo 'TPM鍵を追加しました。既存のパスフレーズは残っています。'
    echo '次の再起動で自動解除を確認してください。失敗した場合は従来のパスフレーズで解除できます。'
    ;;
  *) fail '使い方: bash scripts/tpm.sh {prepare|enroll}' ;;
esac
