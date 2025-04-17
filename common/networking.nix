{ ... }:

{
  # Enable networking
  networking.networkmanager.enable = true;
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
    "8.8.4.4"
    "1.0.0.1"
  ];

  # Firewall is enabled by default but we'll be explicit
  networking.firewall.enable = true;
  services.resolved.enable = true;

  services.tailscale = {
    enable = true;
    extraSetFlags = [
      "--ssh"
      "--webclient"
      "--accept-dns=false"
    ];
  };

  # Don't disconnect ssh mid update
  systemd.services.tailscaled.restartIfChanged = false;
}
