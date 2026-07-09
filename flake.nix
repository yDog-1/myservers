{
  description = "My local servers configuration flake";

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
    system = "aarch64-linux";
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    configRevision = self.shortRev or self.dirtyShortRev or "dirty";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICfgQb8/YcfrNJVF6ho1t4UVj/7Sk6KJ7a2IuHrQ9PA4 ydog-1@nixos"
    ];
    deployAuthorizedKeys = authorizedKeys;
    spec = {
      home-pi = {
        userName = "ydog";
        deployUserName = "deploy";
        ipAddress = "192.168.0.100";
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

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = [
          pkgs.deploy-rs
          pkgs.openssh
          pkgs.git
        ];
        shellHook = ''
          echo "deploy shell: use 'deploy .#home-pi' or 'deploy -i .#home-pi'"
          alias deploy-home-pi='deploy --skip-checks .#home-pi'
        '';
      };
    });
  };
}
