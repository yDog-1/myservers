{
  lib,
  nixos-raspberrypi,
  ...
}: {
  # This is an installed server image, so omit the recovery profile and its ZFS build.
  disabledModules = ["profiles/base.nix"];

  imports = [
    nixos-raspberrypi.nixosModules.sd-image
  ];

  hardware.enableAllHardware = lib.mkForce false;
}
