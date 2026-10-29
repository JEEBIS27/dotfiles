{ appPkgs, ... }:
{
  # Deliberately do not import home.nix: it is the PC profile.
  imports = [ ../modules/common.nix ];

  # Username and homeDirectory come from Nix-on-Droid, not /home/jeebis.
  home.stateVersion = "24.05";
  home.sessionVariables.VISUAL = "hx";
  programs.man.enable = false;
  xdg.mime.enable = false;

  # Use upstream terminal editors on Android. The PC Steel build, its native
  # plugins and desktop theme generator are intentionally outside this profile.
  programs.helix = {
    enable = true;
    package = appPkgs.helix;
    defaultEditor = true;
    settings = {
      theme = "kanagawa";
      editor.true-color = true;
    };
  };

  # Home Manager translates session variables for fish.
}
