{
  spec,
  authorizedKeys,
  deployAuthorizedKeys,
  ...
}: {
  imports = [
    ./pihole.nix
  ];

  system.stateVersion = "26.05";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
  };

  networking = {
    hostName = "home-pi";
    wireless.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network.enable = true;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Name = "enu1u1";
    networkConfig = {
      Address = "${spec.ipAddress}/24";
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
    users."${spec.userName}" = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      hashedPassword = "$y$j9T$VVfvUlUpJuyT9YO5C4Hsd1$bciuoFM3wCnVAioTAAbJ2a8Goa86u3saqvQgzTefAK5";
      openssh.authorizedKeys.keys = authorizedKeys;
    };
    users."${spec.deployUserName}" = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = deployAuthorizedKeys;
    };
  };

  security.sudo.extraRules = [
    {
      users = [spec.deployUserName];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
    randomizedDelaySec = "45min";
    flake = "github:yDog-1/myservers#home-pi";
    flags = [
      "--update-input"
      "nixpkgs"
    ];
    allowReboot = false;
  };
}
