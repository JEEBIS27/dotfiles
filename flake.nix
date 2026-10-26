{
  description = "jeebis personal Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-apps.url = "github:NixOS/nixpkgs/70fdef7c16ffb24c9c74d91c73e438a39b46bfb5";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Keep the official Nix-on-Droid release stack separate from the PC stack.
    nixpkgs-droid.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager-droid = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs-droid";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs-droid";
      inputs.home-manager.follows = "home-manager-droid";
    };
  };

  outputs = { nixpkgs, nixpkgs-apps, home-manager, nixpkgs-droid, home-manager-droid, nix-on-droid, ... }:
    let
      system = "x86_64-linux";
      appPkgs = nixpkgs-apps.legacyPackages.${system};
      mkHome = host: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = { inherit appPkgs; };
        modules = [ host ];
      };
    in {
      nixOnDroidConfigurations.galaxy-tab-s11 = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs-droid {
          system = "aarch64-linux";
          overlays = [ nix-on-droid.overlays.default ];
        };
        home-manager-path = home-manager-droid.outPath;
        extraSpecialArgs.appPkgs = nixpkgs-apps.legacyPackages.aarch64-linux;
        modules = [ ./hosts/nix-on-droid.nix ];
      };

      packages.${system} = let
        steel = import ./packages/helix-steel { pkgs = appPkgs; };
      in {
        mozkey-fcitx5 = import ./packages/mozkey-fcitx5.nix { pkgs = appPkgs; };
        helix-steel = steel.editor;
        helix-steel-plugins = steel.plugins;
        helix-steel-terminal = steel.terminal;
      };
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
