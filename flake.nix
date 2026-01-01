{
  description = "My local servers configuration flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = {nixpkgs, ...}: let
    system = "aarch64-linux";
    home-pi = "home-pi";
  in {
    nixosConfigurations = {
      "${home-pi}" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules/rpi3.nix
          ./modules/swap.nix
          ./modules/base.nix
          ./hosts/${home-pi}
        ];
      };
    };
  };
}
