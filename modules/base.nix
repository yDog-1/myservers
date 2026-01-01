{
  pkgs,
  ...
}: {
  # internationalization settings
  i18n = {
    defaultLocale = "ja_JP.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "ja_JP.UTF-8";
      LC_MONETARY = "ja_JP.UTF-8";
      LC_MEASUREMENT = "ja_JP.UTF-8";
    };
  };

  # Time settings
  time.timezone = "Asia/Tokyo";
  # Enable NTP synchronization
  services.timesyncd.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    unzip
    jq
  ];

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # enable flakes support
  nix.settings.experimental-features = ["nix-command" "flakes"];
}
