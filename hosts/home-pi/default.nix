{pkgs, ...}: let
  name = "home-pi";
in {
  system.stateVersion = "26.05";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
  };

  networking = {
    hostName = name;
    wireless.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network.enable = true;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Name = "enu1u1";
    networkConfig = {
      Address = "192.168.0.100/24";
      Gateway = "192.168.0.1";
    };
  };

  hardware.bluetooth.enable = false;
  boot.kernelParams = [
    "dtoverlay=disable-wifi"
    "dtoverlay=disable-bt"
  ];

  services.openssh = {
    enable = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users = {
    mutableUsers = false;
    users."${name}" = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      hashedPassword = "$y$j9T$Q00T/W9Rn7A/opZPpZ55s/$bxQiybcIhASpEKyj8pFoY6M8RybArcq6XYQ4eptN4AB";
    };
  };

  environment.systemPackages = with pkgs; [
    git
  ];
}
