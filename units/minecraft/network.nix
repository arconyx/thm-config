{ ... }:
{
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

  # TODO: Reenable after exposing via cloudflare tunnel
  # services.caddy.enable = true;
  # services.caddy.virtualHosts.":9010" = {
  #   extraConfig = ''
  #     encode

  #     redir /exposure /exposure/
  #     redir /map /map/

  #     # let people browse their image exports
  #     handle_path /exposure/* {
  #       root * /srv/minecraft/magic/world/exposures
  #       file_server browse
  #     }

  #     handle {
  #       error 404
  #     }

  #     handle_errors {
  #       respond "{err.status_code} {err.status_text}"
  #     }
  #   '';
  # };

  # # so we don't have to chmod exposures world readable
  # systemd.services.caddy.serviceConfig = {
  #   SupplementaryGroups = [ "minecraft" ];
  # };
}
