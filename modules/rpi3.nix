{
  pkgs,
  rpiKernelPackages,
  ...
}: {
  boot = {
    kernelPackages = rpiKernelPackages;
    initrd.availableKernelModules = ["xhci_pci" "usbhid"];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  # The cached NixOS 26.05 kernel lacks metadata expected by newer NixOS modules.
  hardware.deviceTree.enable = true;
  system.boot.loader.kernelFile = "Image";

  hardware.enableRedistributableFirmware = true;
  # Keep the SD image's firmware configured to chainload the extlinux bootloader.
  hardware.raspberry-pi.firmware.uboot = {
    enable = true;
    # Support both the older Pi 3 package and the unified aarch64 package.
    package = pkgs.ubootRaspberryPiAarch64 or pkgs.ubootRaspberryPi3_64bit;
  };
}
