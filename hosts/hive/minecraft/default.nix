{ config, ... }:
{
  imports = [
    ./servers/castle.nix
    ./servers/magic.nix
    ./servers/forever
  ];

  # allow easy interaction with world save
  users.users.arc.extraGroups = [ "minecraft" ];
  users.users.ilphaonar.extraGroups = [ "minecraft" ];

  # Configure backups
  arcworks.services.backups.global = {
    paths = [
      "/etc/cloudflare"
      "/etc/minecraft"
      # /srv/minecraft already added by top level conf including all of /srv
    ];
  };

  # keep dns fresh for server subdomain
  services.cloudflare-dyndns = {
    enable = true;
    frequency = "*:0/15";
    # subdomains of this are handled with a cname atm
    domains = [ "mc.thehivemind.gay" ];
    proxied = false; # no point trying to proxy minecraft
    deleteMissing = false;
    apiTokenFile = "/etc/cloudflare/apikey.env";
  };

  # this is used for webhooks and stuff
  services.caddy.enable = true;
  services.caddy.virtualHosts."hive.thehivemind.gay:80" = {
    extraConfig = ''
      encode

      handle /hooks/* {
        reverse_proxy :${toString config.services.webhook.port}
      }

      handle_path /share/* {
        root /srv/share
        file_server
      }

      redir /forever/map /forever/map/
      handle_path /forever/map/* {
        root * /srv/minecraft/forever/squaremap/web/
        file_server
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
  # so caddy can see the webmap files
  systemd.services.caddy.serviceConfig.SupplementaryGroups = [ "minecraft" ];

  # used for hive.thehivemind.gay
  services.cloudflared = {
    enable = true;
    tunnels.hive = {
      default = "http_status:404";
      credentialsFile = "/etc/cloudflare/tunnel_credentials.json";
    };
  };

  # For Minecraft
  # Option details https://docs.kernel.org/admin-guide/mm/transhuge.html
  boot.kernel.sysfs = {
    kernel.mm.transparent_hugepage = {
      # use thp on request
      enabled = "madvise";
      # use thp on request for shared memory
      shmem_enabled = "advise";
      # if we can't issue thp ignore it but khugepage runs soon to defrag
      # for future calls
      defrag = "defer";
      # explicitly enable defragging by khugepaged
      khugepaged.defrag = "1";
    };
  };

  thm.services.minecraft = {
    enable = true;
    environmentFile = "/etc/minecraft/magic.env";
    rcon-password = "3489trawo5ATpfhaQEQr"; # pragma: allowlist secret
    # https://github.com/Obydux/Minecraft-startup-flags
    jvmOpts = [
      "-Xms8G"
      "-Xmx8G"
      "-XX:+UseZGC"
      "-XX:TrimNativeHeapInterval=5000"
      "-XX:+UseStringDeduplication"
      "-XX:+UseCompactObjectHeaders"
      "-XX:+AlwaysPreTouch"
      "-XX:+UseTransparentHugePages"
      # TODO: Review if we can restrict this
      "--enable-native-access=ALL-UNNAMED"
    ];

    proxy = {
      enable = true;
      openFirewall = true;
      routes =
        let
          servers = config.thm.services.minecraft.servers;
        in
        [
          {
            host = [
              "castle.mc.thehivemind.gay"
            ];
            backend = "localhost:${toString servers.castle.port}";
            fallback = {
              motd = ''
                §cCastle server is offline.
                §eTry necromancy!
              '';
              version.name = "1.21.11";
            };
          }
          {
            host = [
              "magic.mc.thehivemind.gay"
            ];
            backend = "localhost:${toString servers.magic.port}";
            fallback = {
              motd = ''
                §cMagic server is offline.
                §eWe may return later.
              '';
              version.name = "1.20.1 (modded)";
              favicon = ./servers/magic.png;
            };
          }
          {
            host = [
              "192.168.0.131"
              "forever.mc.thehivemind.gay"
              "*"
            ];
            backend = "localhost:${toString servers.forever.port}";
            fallback = {
              motd = ''
                §cForever server is offline.
                §eTry necromancy!
              '';
              version.name = "26.2";
              favicon = ./servers/magic.png;
            };
          }
        ];
    };
  };

}
