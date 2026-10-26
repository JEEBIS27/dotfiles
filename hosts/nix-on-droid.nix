{ appPkgs, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "Asia/Tokyo";
  user.shell = "${appPkgs.zsh}/bin/zsh";
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  home-manager = {
    useGlobalPkgs = true;
    config = import ./android.nix;
    extraSpecialArgs = { inherit appPkgs; };
  };
}
