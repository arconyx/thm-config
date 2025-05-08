{ ... }:
{
  imports = [
    ./../caddy.nix
    ./../tsnsrv.nix
  ];

  # keep dns fresh
  services.cloudflare-dyndns = {
    enable = true;
    frequency = "*:0/15";
    domains = [
      "mc.thehivemind.gay"
    ];
    proxied = false; # no point trying to proxy minecraft
    deleteMissing = true;
    apiTokenFile = "/etc/cloudflare/apikey.env";
  };

  systemd.services.caddy.serviceConfig.SupplementaryGroups = [ "minecraft" ];

  services.tsnsrv.services.map = {
    funnel = true;
    suppressWhois = true; # we won't be using the info anyway
    toURL = "http://127.0.0.1:8100";
  };
}
