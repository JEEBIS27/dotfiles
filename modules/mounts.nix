{ config, lib, pkgs, appPkgs, ... }:
let
  native = config.jeebis.desktop.backend == "nixos";
  # FUSE needs the host's setuid helper, not an unprivileged copy in /nix/store.
  helperDir = if native then "/run/wrappers/bin" else "/usr/bin";
  fusermount = "${helperDir}/fusermount3";
  remoteConfig = "${config.xdg.configHome}/rclone/rclone.conf";
  mounts = { gdrive = "GoogleDrive"; onedrive = "OneDrive"; };
  service = remote: directory: {
    Unit = {
      Description = "Mount ${remote} with rclone";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
      ConditionPathExists = remoteConfig;
    };
    Service = {
      Type = "simple";
      Environment = [ "PATH=${helperDir}:${lib.makeBinPath [ appPkgs.coreutils ]}" ];
      ExecStartPre = "${appPkgs.coreutils}/bin/mkdir -p %h/${directory}";
      ExecStart = "${appPkgs.rclone}/bin/rclone mount ${remote}: %h/${directory} --config ${remoteConfig} --vfs-cache-mode writes --allow-non-empty";
      ExecStop = "${fusermount} -u %h/${directory}";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStopSec = 60;
    };
    Install.WantedBy = [ "default.target" ];
  };
in {
  home.packages = [ appPkgs.rclone ];
  # Keep currently mounted filesystems alive when the unit definition changes.
  systemd.user.startServices = "suggest";
  systemd.user.services = lib.mapAttrs' (remote: directory:
    lib.nameValuePair "rclone-${remote}" (service remote directory)) mounts;
}
