{
  description = "My local servers configuration flake";

  nixConfig = {
    extra-substituters = ["https://nix-community.cachix.org"];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = {
    self,
    nixpkgs,
    deploy-rs,
    ...
  }: let
    imageCache = (import ./flake.nix).nixConfig;
    system = "aarch64-linux";
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    linuxSystems = builtins.filter (system: nixpkgs.lib.hasSuffix "-linux" system) supportedSystems;
    homePiImage = (self.nixosConfigurations.home-pi.extendModules {
      specialArgs.imageSource = self;
      modules = [./hosts/home-pi/image.nix];
    }).config.system.build.sdImage;
    imageTools = forAllSystems (system: import ./pkgs/image-tools {
      pkgs = nixpkgs.legacyPackages.${system};
      # Keep the derivation available without building the ARM image for the shell/apps.
      imageDrv = builtins.unsafeDiscardOutputDependency homePiImage.drvPath;
      nixConfig = imageCache;
    });
    configRevision = self.shortRev or self.dirtyShortRev or "dirty";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICfgQb8/YcfrNJVF6ho1t4UVj/7Sk6KJ7a2IuHrQ9PA4 ydog-1@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBd1PDAJxRBa+urGGUrfzXCHCPe54gbozBQRURMo5bh3 motorola"
    ];
    deployAuthorizedKeys = authorizedKeys;
    spec = {
      home-pi = {
        userName = "ydog";
        deployUserName = "deploy";
        ipAddress = "192.168.0.100";
        image = {
          baseName = "nixos-home-pi-${configRevision}";
          # Keep the installed configuration until these changes are published upstream.
          autoUpgradeEnable = false;
        };
      };
    };
  in {
    nixosConfigurations = {
      home-pi = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          spec = spec."home-pi";
          inherit authorizedKeys;
          inherit deployAuthorizedKeys;
        };
        modules = [
          ({ ... }: {
            system.configurationRevision = configRevision;
          })
          ./modules/rpi3.nix
          ./modules/swap.nix
          ./modules/base.nix
          ./hosts/home-pi
        ];
      };
    };

    packages = forAllSystems (system: imageTools.${system});

    apps = forAllSystems (system: builtins.mapAttrs (_: package: {
      type = "app";
      program = nixpkgs.lib.getExe package;
      meta.description = package.meta.description;
    }) imageTools.${system});

    deploy.nodes.home-pi = let
      home-pi = spec."home-pi";
    in {
      hostname = home-pi.ipAddress;
      sshUser = home-pi.deployUserName;
      remoteBuild = true;
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.home-pi;
      };
    };

    checks = nixpkgs.lib.recursiveUpdate
      (builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib)
      (nixpkgs.lib.genAttrs linuxSystems (system: {
        blocky-config = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/blocky-config-check.nix {
          configFile = ./hosts/home-pi/blocky.yaml;
        };
        image-tools = import ./pkgs/image-tools/check.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };
      }));

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = builtins.attrValues imageTools.${system} ++ [
          pkgs.deploy-rs
          pkgs.openssh
          pkgs.git
        ];
        shellHook = ''
          echo "deploy shell: use 'deploy .#home-pi' or 'deploy -i .#home-pi'"
          alias deploy-home-pi='deploy --skip-checks .#home-pi'
          echo "image tools: export-home-pi-image [--output PATH]"
          ${nixpkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            echo "flash-home-pi-image [--input PATH] DEVICE"
          ''}
        '';
      };
    });
  };
}
