{
  description = "jeebis personal Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-apps.url = "github:NixOS/nixpkgs/70fdef7c16ffb24c9c74d91c73e438a39b46bfb5";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # These upstream projects keep their own tested toolchain/package pins.
    beanKey.url = "git+https://github.com/ph0ryn/beanKey?rev=32929b741155ff29eff2ba13cf2168c59fa0d229&submodules=1";
    hazkey.url = "github:aster-void/nix-hazkey/9524686e361eb1ce9c054f0218e7a4b82091b847";

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

  outputs = { self, beanKey, hazkey, nixpkgs, nixpkgs-apps, home-manager, nixpkgs-droid, home-manager-droid, nix-on-droid, ... }:
    let
      system = "x86_64-linux";
      appPkgs = nixpkgs-apps.legacyPackages.${system};
      pcPkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" "slack" "spotify" "obsidian" ];
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
        jeebis-login-theme = import ./packages/jeebis-login-theme.nix { pkgs = appPkgs; };
        matlab-nix = import ./packages/matlab.nix { pkgs = nixpkgs.legacyPackages.${system}; };
        home-manager = home-manager.packages.${system}.home-manager;
        helium = import ./packages/helium.nix { pkgs = nixpkgs.legacyPackages.${system}; };
        mozkey-fcitx5 = import ./packages/mozkey-fcitx5.nix { pkgs = appPkgs; };
        helix-steel = steel.editor;
        helix-steel-plugins = steel.plugins;
        helix-steel-terminal = steel.terminal;
      };
      homeConfigurations = {
        "jeebis@omarchy" = mkHome ./hosts/omarchy.nix;
        "jeebis@nixos" = mkHome ./hosts/nixos.nix;
      };
      nixosModules.input-method = {
        imports = [ beanKey.nixosModules.default hazkey.nixosModules.hazkey ./nixos/input-method.nix ];
      };
      nixosModules.niri = import ./nixos/niri.nix;
      nixosModules.desktop = self.nixosModules.personal;
      # Compose this with the destination PC's existing configuration.nix.
      nixosModules.personal = {
        imports = [
          home-manager.nixosModules.home-manager
          ./nixos/desktop.nix
          ./nixos/niri.nix
          ./nixos/machine.nix
          beanKey.nixosModules.default hazkey.nixosModules.hazkey ./nixos/input-method.nix
        ];
        _module.args.appPkgs = appPkgs;
        nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" "slack" "spotify" "obsidian" ];
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        home-manager.useGlobalPkgs = true;
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
          ./nixos/niri.nix
          ./nixos/machine.nix
          beanKey.nixosModules.default hazkey.nixosModules.hazkey ./nixos/input-method.nix
          ({ ... }: {
            nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" "slack" "spotify" "obsidian" ];
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
