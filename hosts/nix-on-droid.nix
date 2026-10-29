{ appPkgs, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "Asia/Tokyo";
  user.shell = "${import ../packages/fish.nix { pkgs = appPkgs; }}/bin/fish";
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  home-manager = {
    useGlobalPkgs = true;
    config = import ./android.nix;
    extraSpecialArgs = { inherit appPkgs; };
  };
}
