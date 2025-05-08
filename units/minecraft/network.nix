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

  services.caddy.virtualHosts."http://localhost:9010" = {
    extraConfig = ''
      @exposure path /exposure /exposure/*

      encode

      # let people browse their image exports
      file_server @exposure {
         root /srv/minecraft/magic/exposures
         browse
      }

      # bluemap, stripping prefix
      handle_path /map/ {
        reverse_proxy 8100
      }
    '';
  };

  services.tsnsrv.services.minecraft = {
    funnel = true;
    suppressWhois = true; # we won't be using the info anyway
    toURL = "http://localhost:9010";
  };
}
