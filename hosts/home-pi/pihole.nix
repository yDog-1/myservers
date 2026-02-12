{config, ...}: {
  # Pi-hole uses port 53; disable systemd-resolved to avoid conflicts.
  services.resolved.enable = false;

  # Ensure the host itself uses Pi-hole for DNS.
  networking.nameservers = [
    "127.0.0.1"
  ];

  # pihole-FTL provides DNS (and optionally DHCP) on NixOS.
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallDHCP = true;
    lists = let
      warui = "https://warui.intaa.net/adhosts/";
      blocklist = "https://blocklistproject.github.io/Lists/";
      mkList = url: description: {
        inherit url description;
      };
    in [
      (mkList "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" "Steven Black's unified adlist")
      (mkList (warui + "hosts.txt") "悪いインターネット")
      (mkList (warui + "hosts_ipv6.txt") "悪いインターネット ipv6")
      (mkList (blocklist + "abuse.txt") "悪質サイト")
      (mkList (blocklist + "crypto.txt") "クリプトジャッキング")
      (mkList (blocklist + "fraud.txt") "詐欺サイト")
      (mkList (blocklist + "gambling.txt") "ギャンブル")
      (mkList (blocklist + "malware.txt") "マルウェア")
      (mkList (blocklist + "phishing.txt") "フィッシング")
      (mkList (blocklist + "ransomware.txt") "ランサムウェア")
    ];
    settings = {
      dns = {
        domainNeeded = true;
        expandHosts = true;
        queryLogging = false;
        upstreams = [
          "1.1.1.1"
          "1.0.0.1"
          "8.8.8.8"
          "8.8.4.4"
        ];
      };

      dhcp = {
        active = true;
        start = "192.168.0.50";
        end = "192.168.0.150";
        router = "192.168.0.1";
        netmask = "255.255.255.0";
        leaseTime = "24h";
        ipv6 = true;
      };
    };
  };

  # Restart Pi-hole only when the generated pihole.toml changes.
  systemd.services.pihole-ftl.restartTriggers = [
    config.environment.etc."pihole/pihole.toml".source
  ];

  # Web UI (Pi-hole Dashboard)
  services.pihole-web = {
    enable = true;
    ports = [80];
  };

  # Allow the web UI from your LAN.
  networking.firewall.allowedTCPPorts = [80];
}
