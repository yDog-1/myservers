{...}: {
  # pihole-FTL provides DNS (and optionally DHCP) on NixOS.
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallDHCP = false;
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
