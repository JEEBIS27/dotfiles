#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# The drop-in must preserve all existing hooks and stay idempotent.
HOOKS=(base udev plymouth block encrypt filesystems btrfs-overlayfs)
source "$repo/files/boot/tpm2/mkinitcpio.conf"
[[ ${HOOKS[*]} == 'base udev plymouth block jeebis-tpm2 encrypt filesystems btrfs-overlayfs' ]]
source "$repo/files/boot/tpm2/mkinitcpio.conf"
[[ ${HOOKS[*]} == 'base udev plymouth block jeebis-tpm2 encrypt filesystems btrfs-overlayfs' ]]
HOOKS=(base systemd sd-encrypt filesystems)
source "$repo/files/boot/tpm2/mkinitcpio.conf"
[[ ${HOOKS[*]} == 'base systemd sd-encrypt filesystems' ]]
# A failed TPM attempt must return success so the original encrypt hook runs.
source "$repo/files/boot/tpm2/hook"
jeebis_tpm_record_boot() { :; }
calls=0
resolve_device() { echo /dev/mock-luks; }
getarg() { :; }
modprobe() { :; }
timeout() { calls=$((calls+1)); [[ $* == '15 cryptsetup open --type luks --token-only --token-type=systemd-tpm2 /dev/mock-luks mock-root' ]]; return 1; }
cryptdevice='UUID=mock:mock-root'
run_hook
[[ $calls == 1 ]]
cryptdevice='UUID=mock:mock-root:unknown-option'
run_hook
[[ $calls == 1 ]]
cryptdevice=''
run_hook
[[ $calls == 1 ]]
echo 'TPM boot hook: preserved order, idempotence, option guard and password fallback passed.'
