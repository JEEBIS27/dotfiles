{ config, lib, pkgs, ... }:
let cfg = config.jeebis.boot.tpmUnlock;
in {
  options.jeebis.boot.tpmUnlock = {
    enable = lib.mkEnableOption "Secure Boot and measured TPM2 root-volume unlocking";
    rootName = lib.mkOption {
      type = lib.types.str;
      default = "cryptroot";
      description = "Existing boot.initrd.luks.devices entry; no disk UUID is shared.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [ {
      assertion = (config.boot.initrd.luks.devices.${cfg.rootName}.device or "") != "";
      message = "TPM unlocking requires an existing LUKS root device declaration.";
    } ];
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.tpm2.enable = true;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 4;
      allowUnsigned = false;
      # Firmware key enrollment remains an explicit, host-local operation.
      autoGenerateKeys.enable = false;
      autoEnrollKeys.enable = false;
      measuredBoot = {
        enable = true;
        # PCR4 covers Lanzaboote's verified kernel/initrd/cmdline; PCR7 covers
        # Secure Boot policy. pcrlock predicts accepted boot generations.
        pcrs = [ 4 7 ];
        autoCryptenroll.enable = false;
      };
    };
    boot.initrd.luks.devices.${cfg.rootName}.crypttabExtraOpts = [ "tpm2-device=auto" ];
    environment.systemPackages = [ pkgs.sbctl pkgs.cryptsetup ];
  };
}
