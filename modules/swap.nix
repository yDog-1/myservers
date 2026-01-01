{...}: let
  swapSize = 1024; # MB
  zramPer = 50;
  zramPriority = 100;
in {
  boot.kernel.sysctl."vm.swappiness" = 10;

  swapDevices = [
    {
      device = "/swapfile";
      size = swapSize;
    }
  ];

  zramSwap = {
    enable = true;
    memoryPercent = zramPer;
    priority = zramPriority;
  };
}
