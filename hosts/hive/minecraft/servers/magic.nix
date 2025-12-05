{
  config,
  thm-modpack,
  lib,
  pkgs,
  ...
}:
let
  modpack = thm-modpack.packages.${config.nixpkgs.hostPlatform.system}.default;
  mcVersion = modpack.manifest.versions.minecraft;
  fabricVersion = modpack.manifest.versions.fabric;
  serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
in
{
  thm.services.minecraft.servers.magic = {
    enable = true;
    package = pkgs.fabricServers.${serverVersion}.override {
      loaderVersion = fabricVersion;
      jre_headless = pkgs.graalvmPackages.graalvm-oracle;
    };
    port = 25565;
    settings = {
      gamemode = "survival";
      difficulty = "hard";
      motd = "Operating by necromantic reanimation";
      distance = {
        view = 8;
        simulation = 8;
      };
    };
    symlinks = modpack.modLinks;
    files = {
      "config" = "${modpack}/config";
      "kubejs" = "${modpack}/kubejs";
    };
  };

  # make exposures photos accessible on the interwebs
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
