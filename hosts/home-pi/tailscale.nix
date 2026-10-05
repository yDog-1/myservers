{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # File transfers use the existing SSH service instead of Taildrop.
    disableTaildrop = true;
    extraSetFlags = [
      # Keep using the local Pi-hole resolver.
      "--accept-dns=false"
      # Use the existing OpenSSH service and authorized keys.
      "--ssh=false"
    ];
  };
}
