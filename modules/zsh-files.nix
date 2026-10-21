{ config, pkgs, ... }:
{
  # Preserve the existing startup order and keymaps.
  home.file.".zshrc".source = pkgs.writeText "zshrc-shared-theme" (builtins.replaceStrings [ "@themeDir@" ] [ config.jeebis.desktop.themeDirectory ] (builtins.readFile ../files/zshrc));
  xdg.configFile = {
    "zsh/config.sh".source = ../files/zsh/config.sh;
    "zsh/fzf.zsh".source = ../files/zsh/fzf.zsh;
    "zsh/my_alias.zsh".source = ../files/zsh/my_alias.zsh;
    "zsh/unified_keys.zsh".source = ../files/zsh/unified_keys.zsh;
    "sheldon/plugins.toml".source = ../files/sheldon/plugins.toml;
  };
}
