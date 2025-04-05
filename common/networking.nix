{ ... }:

{
  # Enable networking
  networking.networkmanager.enable = true;

  # Firewall is enabled by default but we'll be explicit
  networking.firewall.enable = true;

  # TODO: Tailscale auth
  services.resolved.enable = true;
  services.tailscale = {
    enable = true;
    extraSetFlags = [
      "--ssh"
      "--webclient"
      "--accept-dns=false"
    ];
  };
}
