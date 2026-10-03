{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # Taildrop can bypass network access rules; this host only needs SSH.
    disableTaildrop = true;
    extraSetFlags = [
      # Keep using the local Pi-hole resolver.
      "--accept-dns=false"
      # Use the existing OpenSSH service and authorized keys.
      "--ssh=false"
      "--advertise-tags=tag:home-pi"
    ];
  };
}
