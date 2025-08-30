{ config, ... }:
{
  imports = [ ./webhook.nix ];

  arcworks.services.backups.global.paths = [ "/etc/cloudflare" ];

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

  services.caddy.enable = true;
  services.caddy.virtualHosts."hive.thehivemind.gay:80" = {
    extraConfig = ''
      encode

      handle /hooks/* {
        reverse_proxy :${builtins.toString config.services.webhook.port}
      }

      # let people browse their image exports
      redir /exposure /exposure/
      handle_path /exposure/* {
        root * /srv/minecraft/magic/world/exposures
        file_server browse
      }

      # this handle matches all requests so anything else
      # needs to be in a handle or handle_path block of their own
      handle {
        error 404
      }

      handle_errors {
        respond "{err.status_code} {err.status_text}"
      }
    '';
  };

  # so we don't have to chmod exposures world readable
  systemd.services.caddy.serviceConfig = {
    SupplementaryGroups = [ "minecraft" ];
  };

  services.cloudflared = {
    enable = true;
    tunnels.hive = {
      default = "http_status:404";
      credentialsFile = "/etc/cloudflare/tunnel_credentials.json";
    };
  };
}
