{ lib, ... }:

{
  # Enable networking
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "eno1";
    # dhcp is giving us .138 for some reason
    address = [ "192.168.0.131/24" ];
    networkConfig = {
      # start a DHCP Client for IPv4 Addressing/Routing
      DHCP = "ipv4";
      # accept Router Advertisements for Stateless IPv6 Autoconfiguraton (SLAAC)
      IPv6AcceptRA = true;
    };
    dhcpServerConfig = {
      PersistLeases = "no";
    };
    # make routing on this interface a dependency for network-online.target
    linkConfig.RequiredForOnline = "routable";
  };

  # dhcp gives us some questionable nameservers
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
    "8.8.4.4"
    "1.0.0.1"
  ];

  # Firewall is enabled by default but we'll be explicit
  networking.firewall.enable = true;
  services.resolved.enable = true;

  arcworks.network.tailnet.enable = true;
  services.tailscale.extraSetFlags = [
    # Needed to access tailscale serve routes prior to v1.94
    "--accept-routes"
  ];
}
