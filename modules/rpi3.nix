{
  nixos-raspberrypi,
  ...
}: {
  imports = [nixos-raspberrypi.nixosModules.raspberry-pi-3.base];

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [
      "noatime"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
    ];
  };
}
