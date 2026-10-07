{
  lib,
  spec,
  imageSource,
  ...
}: {
  imports = [../../modules/sd-image.nix];

  system.autoUpgrade.enable = lib.mkForce spec.image.autoUpgradeEnable;

  sdImage.populateRootCommands = lib.mkAfter ''
    mkdir -p ./files/etc/nixos
    cp -r ${imageSource}/flake.nix ${imageSource}/flake.lock ${imageSource}/hosts ${imageSource}/modules ${imageSource}/pkgs ./files/etc/nixos/
  '';
}
