{ lib, ... }:
{
  imports = [ ./cli.nix ./zsh-files.nix ];

  options.jeebis.shell.themeDirectory = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Optional generated terminal theme directory; empty uses built-in colors.";
  };
}
