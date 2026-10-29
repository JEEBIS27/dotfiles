{ lib, appPkgs, ... }:
{
  imports = [ ./cli.nix ./fish.nix ];

  options.jeebis.shell.package = lib.mkOption {
    type = lib.types.package;
    default = import ../packages/fish.nix { pkgs = appPkgs; };
    description = "fish with the unified TTY interrupt key initialized before startup.";
  };

  options.jeebis.shell.themeDirectory = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Optional generated terminal theme directory; empty uses built-in colors.";
  };
}
