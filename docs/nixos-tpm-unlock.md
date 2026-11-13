# TPM root-volume unlocking

This is an opt-in NixOS boot module, not a Home Manager setting. Importing the
personal profile alone does not enable it. Disk UUIDs remain in the destination
machine's hardware configuration. No encryption is removed or reformatted.

`nixos/tpm-unlock.nix` uses pinned Lanzaboote v1.2.0, signed boot artifacts,
systemd initrd, TPM2 and a systemd-pcrlock policy for PCR4 (the verified boot
chain) and PCR7 (Secure Boot policy). Up to four generations remain bootable.
The install hook predicts accepted boot generations rather than sealing to a
single kernel hash. This requires real-machine acceptance; no successful boot
or automatic unlock is implied by the source configuration.

## Stages

1. Run `just prepare-tpm` on the target. It validates the generated integration
   flake format, creates local sbctl keys if absent, backs up `/etc/nixos`, adds
   an optional host-local `jeebis-boot.nix`, and enables the module there.
   It does not activate a generation, enroll firmware/LUKS keys, or reboot.
2. Run `just switch`. Stop on any error. A successful activation signs and
   installs boot artifacts but does not enable Secure Boot in firmware.
3. Review `sudo sbctl verify` and the installed boot entries. Confirm the new
   signed NixOS entries and systemd-boot are signed. Other leftover unsigned
   files may be listed; do not blindly enroll keys or delete boot files.
4. Configure UEFI Setup Mode using the board's instructions, preserving dbx.
   Do not clear all Secure Boot databases. Enroll the prepared keys with
   `sudo sbctl enroll-keys --microsoft --firmware-builtin` after confirming the
   firmware is in Setup Mode. These flags preserve Windows/OptionROM support;
   never force enrollment past sbctl's hardware warnings. Do not overwrite the
   Windows ESP or disable its boot entry. Firmware keys and signing keys are
   host-specific and must never be committed.
5. Boot the signed NixOS generation with Secure Boot enabled and confirm
   `sudo bootctl status --no-pager` reports `Secure Boot: enabled (user)`.
   The existing disk passphrase is still needed at this stage.
6. Run `just enroll-tpm`. It requires Secure Boot, the current booted generation,
   an open cryptroot LUKS2 mapping and the measured-boot policy. It adds a TPM
   slot after prompting for the existing passphrase. A root-only LUKS header backup
   is saved under `/var/lib/jeebis-nixos-tpm/backup` first. It neither deletes old
   slots nor overwrites an existing TPM registration. Reboot and verify.

A regular passphrase stays available if the TPM policy cannot be satisfied.
Keep the signing keys and LUKS recovery material backed up outside Git. Firmware,
Secure Boot database or boot-chain changes may require policy repair while
unlocked with the existing passphrase. Do not disable encryption or reset TPM
as part of this setup.

To stop using the opt-in module, restore the saved configuration or remove
`/etc/nixos/jeebis-boot.nix`, then rebuild while Secure Boot is disabled if the
replacement generation is unsigned. Removing the Nix option alone does not
remove an already enrolled TPM token from the LUKS header.

Sources:
- https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html
- https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html
- https://nix-community.github.io/lanzaboote/explanation/measured-boot.html
- https://www.freedesktop.org/software/systemd/man/260/systemd-cryptenroll.html
