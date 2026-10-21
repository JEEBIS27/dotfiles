{
  description = "jeebis personal Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-apps.url = "github:NixOS/nixpkgs/70fdef7c16ffb24c9c74d91c73e438a39b46bfb5";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-apps, home-manager, ... }:
    let
      system = "x86_64-linux";
      appPkgs = nixpkgs-apps.legacyPackages.${system};
      mkHome = host: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = { inherit appPkgs; };
        modules = [ host ];
      };
    in {
      packages.${system}.mozkey-fcitx5 = import ./packages/mozkey-fcitx5.nix { pkgs = appPkgs; };
      homeConfigurations = {
        "jeebis@omarchy" = mkHome ./hosts/omarchy.nix;
        "jeebis@nixos" = mkHome ./hosts/nixos.nix;
      };
      nixosModules.desktop = import ./nixos/desktop.nix;
      # Compose this with the destination PC's existing configuration.nix.
      nixosModules.personal = {
        imports = [
          home-manager.nixosModules.home-manager
          ./nixos/desktop.nix
        ];
        _module.args.appPkgs = appPkgs;
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit appPkgs; };
        home-manager.users.jeebis = import ./hosts/nixos.nix;
      };
      nixosConfigurations.desktop-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit appPkgs; };
        modules = [
          home-manager.nixosModules.home-manager
          ./nixos/desktop.nix
          ({ ... }: {
            system.stateVersion = "26.05";
            virtualisation.vmVariant = { virtualisation.memorySize = 4096; virtualisation.cores = 4; };
            boot.loader.grub.enable = false;
            fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
            users.users.jeebis = { isNormalUser = true; extraGroups = [ "wheel" "networkmanager" ]; };
            # Make HM applications available in NixOS login and user-service PATHs.
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit appPkgs; };
            home-manager.users.jeebis = import ./hosts/nixos.nix;
          })
        ];
      };
    };
}
