#!/usr/bin/env bash
# Existing Arch/Omarchy host only. Keep password slots and the stock boot hooks.
set -euo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Run with sudo (enrollment needs a private terminal prompt).' >&2; exit 1; }
mode=${1:-status}
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
state=/var/lib/jeebis-tpm-unlock
cryptarg=$(tr ' ' '\n' </proc/cmdline | sed -n 's/^cryptdevice=//p')
[[ $cryptarg == UUID=*:* ]] || { echo 'Expected the existing cryptdevice=UUID=...:name boot path.' >&2; exit 1; }
IFS=: read -r identity mapper options <<<"$cryptarg"
uuid=${identity#UUID=}
device=/dev/disk/by-uuid/$uuid
[[ -z ${options:-} && -b $device && -c /dev/tpmrm0 ]] || { echo 'TPM2 or supported encrypted root is unavailable.' >&2; exit 1; }
[[ $(cryptsetup luksDump "$device" | awk '$1=="Version:" {print $2}') == 2 ]] || { echo 'LUKS2 is required.' >&2; exit 1; }
case $mode in
 status)
    systemd-analyze has-tpm2
    cryptsetup luksDump "$device" | sed -n '/Tokens:/,/Digests:/p'
    ;;
 prepare)
    [[ -x /usr/bin/limine-mkinitcpio ]] || { echo 'Limine/mkinitcpio is required.' >&2; exit 1; }
    [[ ! -e $state/prepared-boot-id ]] || { echo 'Preparation already exists; do not overwrite its boot backup.' >&2; exit 1; }
    mkdir -p "$state/backup"
    chmod 700 "$state" "$state/backup"
    cryptsetup luksHeaderBackup "$device" --header-backup-file "$state/backup/luks-header"
    cp -a /boot "$state/backup/boot"
    cp -a /etc/sddm.conf "$state/backup/sddm.conf"
    for file in /etc/initcpio/install/jeebis-tpm2 /etc/initcpio/hooks/jeebis-tpm2 /etc/mkinitcpio.conf.d/zz-jeebis-tpm2.conf; do
        [[ ! -e $file ]] || { echo "Refusing to replace existing $file" >&2; exit 1; }
    done
    prepare_failed() {
        result=$?
        if [[ $result -ne 0 ]]; then
            rm -f /etc/initcpio/install/jeebis-tpm2 /etc/initcpio/hooks/jeebis-tpm2 /etc/mkinitcpio.conf.d/zz-jeebis-tpm2.conf
            cp -a "$state/backup/boot/." /boot/
            echo "Build failed; original boot files restored from $state/backup." >&2
        fi
    }
    trap prepare_failed EXIT
    install -Dm755 "$repo/files/boot/tpm2/install" /etc/initcpio/install/jeebis-tpm2
    install -Dm755 "$repo/files/boot/tpm2/hook" /etc/initcpio/hooks/jeebis-tpm2
    install -Dm644 "$repo/files/boot/tpm2/mkinitcpio.conf" /etc/mkinitcpio.conf.d/zz-jeebis-tpm2.conf
    # Keep this only on success. Password fallback remains available even with no token.
    limine-mkinitcpio
    trap - EXIT
    cat /proc/sys/kernel/random/boot_id >"$state/prepared-boot-id"
    printf '%s\n' "$uuid" >"$state/root-uuid"
    echo 'Prepared. Reboot once and unlock using the existing disk passphrase.'
    echo 'Then run this script with enroll. No password slot was removed; autologin is unchanged.'
    ;;
 enroll)
    [[ -f $state/prepared-boot-id && $(cat "$state/root-uuid") == "$uuid" ]] || { echo 'Run prepare first.' >&2; exit 1; }
    [[ $(cat "$state/prepared-boot-id") != $(cat /proc/sys/kernel/random/boot_id) ]] || { echo 'Reboot into the prepared UKI before enrollment.' >&2; exit 1; }
    [[ -f /run/jeebis-tpm2/boot-id && $(cat /run/jeebis-tpm2/boot-id) == $(cat /proc/sys/kernel/random/boot_id) ]] || { echo 'The running boot did not execute the prepared TPM hook.' >&2; exit 1; }
    [[ -t 0 ]] || { echo 'Enrollment requires a private terminal, not chat or a pipe.' >&2; exit 1; }
    # Bind firmware (0/2), bootloader/UKI (4), Secure Boot policy (7),
    # initrd (9), and command-line overrides (12). Updates can require re-enrollment.
    # PCR7-only enrollment is insufficient while Secure Boot is disabled.
    systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+2+4+7+9+12 --tpm2-with-pin=no "$device"
    cryptsetup open --test-passphrase --token-only --token-type=systemd-tpm2 "$device"
    python3 - <<'PY'
import configparser
from pathlib import Path
p=Path('/etc/sddm.conf')
c=configparser.ConfigParser(interpolation=None);c.optionxform=str;c.read(p)
if not c.has_section('Autologin'):c.add_section('Autologin')
c['Autologin']['User']=''
c['Autologin']['Relogin']='false'
with p.open('w') as f:c.write(f)
PY
    echo 'TPM token verified; password slots retained. SDDM autologin disabled for the next boot.'
    echo 'Kernel/boot updates may require the disk passphrase and a new TPM enrollment.'
    ;;
 *) echo 'Usage: setup-tpm-unlock.sh {status|prepare|enroll}' >&2; exit 2 ;;
esac
