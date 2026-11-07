{ config, lib, appPkgs, ... }:
{
  imports = [ ./cli.nix ./fish.nix ];

  options.jeebis.shell.enablePathStyleProvider = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable the optional generic path-style hook; false uses upstream fish unchanged.";
  };

  options.jeebis.shell.package = lib.mkOption {
    type = lib.types.package;
    default = import ../packages/fish.nix {
      pkgs = appPkgs;
      inherit (config.jeebis.shell) enablePathStyleProvider;
    };
    description = "fish with the unified TTY interrupt key initialized before startup.";
  };

  options.jeebis.shell.themeDirectory = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Optional generated terminal theme directory; empty uses built-in colors.";
  };
}
