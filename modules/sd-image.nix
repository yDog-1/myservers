{
  lib,
  modulesPath,
  ...
}: {
  # This is an installed server image, so omit the recovery profile and its ZFS build.
  disabledModules = ["profiles/base.nix"];

  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  hardware.enableAllHardware = lib.mkForce false;
  sdImage.firmwareSize = 64;
}
