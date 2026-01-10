{...}: {
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
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
        description = "Steven Black's unified adlist";
      }
      {
        url = "https://warui.intaa.net/adhosts/hosts.txt";
        description = "悪いインターネット";
      }
      {
        url = "https://warui.intaa.net/adhosts/hosts_ipv6.txt";
        description = "悪いインターネット ipv6";
      }
    ];
    settings = {
      dns = {
        domainNeeded = true;
        expandHosts = true;
        queryLogging = false;
        upstreams = [
          "1.1.1.1"
          "1.0.0.1"
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

  # Web UI (Pi-hole Dashboard)
  services.pihole-web = {
    enable = true;
    ports = [80];
  };

  # Allow the web UI from your LAN.
  networking.firewall.allowedTCPPorts = [80];
}
