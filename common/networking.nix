{ ... }:

{
  # Enable networking
  networking.networkmanager = {
    enable = true;
    ensureProfiles.profiles = {
      "wired" = {
        connection = {
          autoconnect = true;
          autoconnect-priority = "500";
          id = "wired";
          interface-name = "eno1";
          type = "ethernet";
          uuid = "f98205ef-5e61-3c6c-b1df-eace732ce8ee";
        };
        ethernet = { };
        ipv4 = {
          method = "auto";
          # route-metric = "20";
          ignore-auto-dns = true;
        };
        ipv6 = {
          addr-gen-mode = "default";
          method = "auto";
          # route-metric = "20";
          ignore-auto-dns = true;
        };
        proxy = { };
      };
    };
  };
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
