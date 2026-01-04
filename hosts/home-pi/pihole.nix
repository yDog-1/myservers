{...}: {
  # pihole-FTL provides DNS (and optionally DHCP) on NixOS.
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallDHCP = false;
    queryLogDeleter.enable = true;
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
        description = "Steven Black's unified adlist";
      }
    ];
    settings = {
      dns = {
        domainNeeded = true;
        expandHosts = true;
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
