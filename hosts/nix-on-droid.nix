{ appPkgs, nix-index-database, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "Asia/Tokyo";
  user.shell = "${import ../packages/fish.nix { pkgs = appPkgs; }}/bin/fish";
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  home-manager = {
    useGlobalPkgs = true;
    config = {
      imports = [
        nix-index-database.homeModules.nix-index
        ./android.nix
      ];
      programs.nix-index.enable = true;
      programs.nix-index-database.comma.enable = true;
    };
    extraSpecialArgs = { inherit appPkgs; };
  };
}
