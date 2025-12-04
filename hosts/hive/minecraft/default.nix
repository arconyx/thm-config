{ config, ... }:
{
  imports = [ ./servers/magic.nix ];

  # allow easy interaction with world save
  users.users.arc.extraGroups = [ "minecraft" ];

  # Configure backups
  arcworks.services.backups.global = {
    paths = [
      "/etc/cloudflare"
      "/etc/minecraft"
      # /srv/minecraft already added by top level conf including all of /srv
    ];
    exclude = [
      # Distant horizons files can be regenerated
      "DistantHorizons.sqlite"
      "DistantHorizons.sqlite-shm"
      "DistantHorizons.sqlite-wal"
      "/srv/minecraft/backup" # don't want to waste storage backing up the local backups
    ];
  };

  # keep dns fresh for server subdomain
  services.cloudflare-dyndns = {
    enable = true;
    frequency = "*:0/15";
    domains = [
      "mc.thehivemind.gay"
    ];
    proxied = false; # no point trying to proxy minecraft
    deleteMissing = false;
    apiTokenFile = "/etc/cloudflare/apikey.env";
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

  thm.services.minecraft = {
    enable = true;
    environmentFile = "/etc/minecraft/magic.env";
    rcon-password = "3489trawo5ATpfhaQEQr"; # pragma: allowlist secret
    jvmOpts = [
      "-Xms8G"
      "-Xmx8G"
      "-XX:+UnlockExperimentalVMOptions"
      "-XX:+UnlockDiagnosticVMOptions"
      "-XX:+AlwaysActAsServerClassMachine"
      "-XX:+AlwaysPreTouch"
      "-XX:+DisableExplicitGC"
      "-XX:+UseNUMA"
      "-XX:AllocatePrefetchStyle=3"
      "-XX:NmethodSweepActivity=1"
      "-XX:ReservedCodeCacheSize=400M"
      "-XX:NonNMethodCodeHeapSize=12M"
      "-XX:ProfiledCodeHeapSize=194M"
      "-XX:NonProfiledCodeHeapSize=194M"
      "-XX:-DontCompileHugeMethods"
      "-XX:+PerfDisableSharedMem"
      "-XX:+UseFastUnorderedTimeStamps"
      "-XX:+UseCriticalJavaThreadPriority"
      "-XX:+EagerJVMCI"
      "-Dgraal.TuneInlinerExploration=1"
      "-Djdk.graal.CompilerConfiguration=enterprise"
      "-XX:+UseG1GC"
      "-XX:MaxGCPauseMillis=130"
      "-XX:G1NewSizePercent=28"
      "-XX:G1HeapRegionSize=16M"
      "-XX:G1ReservePercent=20"
      "-XX:G1MixedGCCountTarget=3"
      "-XX:InitiatingHeapOccupancyPercent=10"
      "-XX:G1MixedGCLiveThresholdPercent=90"
      "-XX:G1RSetUpdatingPauseTimePercent=0"
      "-XX:SurvivorRatio=32"
      "-XX:MaxTenuringThreshold=1"
      "-XX:G1SATBBufferEnqueueingThresholdPercent=30"
      "-XX:G1ConcMarkStepDurationMillis=5"
      "-XX:+UseTransparentHugePages"
      "-XX:ConcGCThreads=6"
      "--enable-native-access=ALL-UNNAMED"
    ];
  };

}
