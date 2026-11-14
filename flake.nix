{
  description = "jeebis personal Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-apps.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Published source only: target PCs do not need the local development checkout.
    mejiroime = {
      url = "git+https://github.com/JEEBIS27/MejiroIME.git?rev=2047fb9ad6b426cf91b325aee3a7c3a4e00107b3";
      flake = false;
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

  outputs = { self, mejiroime, lanzaboote, nixpkgs, nixpkgs-apps, home-manager, nixpkgs-droid, home-manager-droid, nix-on-droid, ... }:
    let
      system = "x86_64-linux";
      appPkgs = import nixpkgs-apps {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" "slack" "spotify" "obsidian" "1password" "1password-cli" ];
      };
      pcPkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" "slack" "spotify" "obsidian" "1password" "1password-cli" ];
      };
      mkHome = host: home-manager.lib.homeManagerConfiguration {
        pkgs = pcPkgs;
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

      # Bootstrap tools use the same app pin as the installed CLI tools.
      packages.aarch64-linux.just = nixpkgs-apps.legacyPackages.aarch64-linux.just;
      packages.${system} = let
        steel = import ./packages/helix-steel { pkgs = appPkgs; };
      in {
        chatgpt = import ./packages/chatgpt.nix { pkgs = pcPkgs; };
        herdr-app = import ./packages/herdr-app.nix { pkgs = nixpkgs.legacyPackages.${system}; };
        herdr-core = import ./packages/herdr-core.nix { pkgs = nixpkgs.legacyPackages.${system}; };
        tide-island = import ./packages/tide-island.nix { pkgs = appPkgs; };
        just = appPkgs.just;
        sbctl = pcPkgs.sbctl;
        spotify = import ./packages/spotify.nix { pkgs = pcPkgs; };
        jeebis-login-theme = import ./packages/jeebis-login-theme.nix { pkgs = appPkgs; };
        matlab-nix = import ./packages/matlab.nix { pkgs = nixpkgs.legacyPackages.${system}; };
        home-manager = home-manager.packages.${system}.home-manager;
        helium = import ./packages/helium.nix { pkgs = nixpkgs.legacyPackages.${system}; };
        helix-steel = steel.editor;
        helix-steel-plugins = steel.plugins;
        helix-steel-terminal = steel.terminal;
      };
      homeConfigurations = {
        "jeebis@omarchy" = mkHome ./hosts/omarchy.nix;
        "jeebis@nixos" = mkHome ./hosts/nixos.nix;
      };
      nixosModules.input-method = {
        imports = [ (mejiroime + "/nix/nixos.nix") ./nixos/input-method.nix ];
        _module.args.mejiroSource = mejiroime;
        _module.args.appPkgs = appPkgs;
      };
      nixosModules.tpm-unlock = {
        imports = [ lanzaboote.nixosModules.lanzaboote ./nixos/tpm-unlock.nix ];
      };
      nixosModules.niri = import ./nixos/niri.nix;
      nixosModules.desktop = self.nixosModules.personal;
      # Compose this with the destination PC's existing configuration.nix.
      nixosModules.personal = {
        imports = [
          home-manager.nixosModules.home-manager
          self.nixosModules.tpm-unlock
          ./nixos/desktop.nix
          ./nixos/niri.nix
          ./nixos/machine.nix
          (mejiroime + "/nix/nixos.nix") ./nixos/input-method.nix
        ];
        _module.args.appPkgs = appPkgs;
        _module.args.mejiroSource = mejiroime;
        nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" "slack" "spotify" "obsidian" "1password" "1password-cli" ];
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit appPkgs; };
        home-manager.users.jeebis = import ./hosts/nixos.nix;
      };
      nixosConfigurations.desktop-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit appPkgs; mejiroSource = mejiroime; };
        modules = [
          home-manager.nixosModules.home-manager
          self.nixosModules.tpm-unlock
          ./nixos/desktop.nix
          ./nixos/niri.nix
          ./nixos/machine.nix
          (mejiroime + "/nix/nixos.nix") ./nixos/input-method.nix
          ({ ... }: {
            nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" "slack" "spotify" "obsidian" "1password" "1password-cli" ];
            system.stateVersion = "26.05";
            virtualisation.vmVariant = { virtualisation.memorySize = 4096; virtualisation.cores = 4; };
            boot.loader.grub.enable = false;
            fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
            users.users.jeebis = { isNormalUser = true; extraGroups = [ "wheel" "networkmanager" ]; };
            # Make HM applications available in NixOS login and user-service PATHs.
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit appPkgs; };
            home-manager.users.jeebis = import ./hosts/nixos.nix;
          })
        ];
      };
    };
}
