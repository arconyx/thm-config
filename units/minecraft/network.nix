{ lib, ... }:
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

  services.caddy.virtualHosts.":9010" = {
    extraConfig = ''
      encode

      redir /exposure /exposure/
      redir /map /map/

      # let people browse their image exports
      handle_path /exposure/* {
        root * /srv/minecraft/magic/world/exposures
        file_server browse
      }

      # bluemap, stripping prefix
      handle_path /map/* {
        reverse_proxy :8100
      }

      handle {
        error 404
      }

      handle_errors {
        respond "{err.status_code} {err.status_text}"
      }
    '';
  };

  users.users.minecraft.homeMode = lib.mkForce "771";

  services.tsnsrv.services.minecraft = {
    funnel = true;
    suppressWhois = true;
    toURL = "http://127.0.0.1:9010";
  };
}
