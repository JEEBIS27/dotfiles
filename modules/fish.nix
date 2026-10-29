{ config, options, pkgs, lib, appPkgs, ... }:
let
  plugins = import ../packages/fish-plugins.nix { pkgs = appPkgs; };
  extractPlugin = (lib.findFirst (p: p.name == "fish-extract") null plugins).src;
in {
  programs.fish = {
    enable = true;
    inherit plugins;
    package = config.jeebis.shell.package;
    loginShellInit = ''
      # Import the host's POSIX login environment (Nix daemon, Omarchy, locale).
      if test -r /etc/profile
        for entry in (${appPkgs.bash}/bin/bash -c 'source /etc/profile; env -0' | string split0)
          set -l pair (string split -m 1 = -- "$entry")
          if string match -rq '^[A-Za-z_][A-Za-z0-9_]*$' -- "$pair[1]"; and not contains -- "$pair[1]" PWD SHLVL _
            set -gx $pair[1] "$pair[2]"
          end
        end
      end
    '';
    interactiveShellInit = lib.mkAfter ''
      ${appPkgs.nix-your-shell}/bin/nix-your-shell fish | source
      ${appPkgs.carapace}/bin/carapace _carapace fish | source
      source ${config.xdg.configHome}/fish/jeebis-config.fish
    '';
  } // lib.optionalAttrs (options.programs.fish ? generateCompletions) {
    generateCompletions = false;
  };
  # HM 24.05 has no switch for its removed Python manpage-completion generator.
  # Use native fish/package completions on both HM versions.
  xdg.dataFile = lib.optionalAttrs (!(options.programs.fish ? generateCompletions)) {
    "fish/home-manager_generated_completions".source = lib.mkForce
      (pkgs.runCommand "fish-native-completions" {} "mkdir -p $out");
  };
  home.packages = with appPkgs; [
    nix-your-shell carapace fish-lsp grc curl jq openssh libnotify
  ];
  programs.atuin = {
    enable = true;
    package = appPkgs.atuin;
    enableFishIntegration = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
    flags = [ "--disable-up-arrow" "--disable-ai" ];
  };
  programs.fzf = {
    enable = true;
    package = appPkgs.fzf;
    enableFishIntegration = false;
    enableZshIntegration = false;
    enableBashIntegration = false;
  };
  programs.zoxide = {
    enable = true;
    package = appPkgs.zoxide;
    enableFishIntegration = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
    options = [ "--cmd" "cd" ];
  };
  xdg.configFile = {
    "fish/jeebis-config.fish".text = builtins.replaceStrings
      [ "@themeDir@" "@extractPlugin@" ] [ config.jeebis.shell.themeDirectory (toString extractPlugin) ]
      (builtins.readFile ../files/fish/config.fish);
    "fish/jeebis-prompt.fish".source = ../files/fish/prompt.fish;
    "fish/jeebis-functions.fish".source = ../files/fish/functions.fish;
    "fish/jeebis-keys.fish".source = ../files/fish/keys.fish;
  };
}
