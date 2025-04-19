{
  pkgs,
  lib,
  config,
  ...
}:
let
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/ArcOnyx/thm-modpack/raw/5941de90c6e15afc9ca51d8b2cf4e8a483fdb1a2/pack.toml";
    packHash = "sha256-a08qlvzSxESRiU+ReJbonMNHPyfc9G/geydiIH7yct4=";
    manifestHash = "sha256:19j4riin6g5srrj7mib2m9qvl0d80q8s3dvqffc21ic2gkyql5i1";
  };
  mcVersion = modpack.manifest.versions.minecraft;
  fabricVersion = modpack.manifest.versions.fabric;
  serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
in
{
  imports = [ ./postgresql.nix ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    dataDir = "/srv/minecraft";
    managementSystem = {
      tmux.enable = false;
      systemd-socket.enable = true;
    };
    servers.magic = {
      enable = true;
      package = pkgs.fabricServers.${serverVersion}.override { loaderVersion = fabricVersion; };
      autoStart = true;
      operators = {
        ArcOnyx = {
          uuid = "36322fea-3925-4ee1-a160-1f068e7cef44";
          level = 4;
          bypassesPlayerLimit = true;
        };
        Qyila = {
          uuid = "9aba3284-1e93-4e49-a8f4-73a9fbe2a3e3";
          level = 3;
        };
        Sithisilith = {
          uuid = "b4807d95-aaf5-4654-b226-a2d278a71553";
          level = 2;
        };
        FISHYNZ_ = {
          uuid = "53a2148c-0690-4aa0-b75a-2072d78a772a";
          level = 2;
        };
      };
      jvmOpts = "-Xms6144M -Xmx8192M";
      serverProperties = {
        level-seed = "thehivemind";
        gamemode = "survival";
        enable-command-block = true;
        motd = "Test server";
        difficulty = "hard";
        allow-flight = "true";
        view-distance = 16;
        server-port = 25565;
        white-list = true;
        enforce-whitelist = true;
        spawn-protection = 0;
      };
      symlinks = {
        "mods" = "${modpack}/mods";
      };
      files = {
        "config" = "${modpack}/config";
        "config/ledger.toml".value = {
          database = {
            queueTimeoutMin = 5; # The maximum amount of time to wait for the queue to drain when the server stops
            queueCheckDelaySec = 10; # The amount of time between checking if the queue is empty when the server stops
            autoPurgeDays = -1; # Automatically purge entries older than the number of days specified. Set to -1 to disable
          };
          search = {
            pageSize = 8; # Number of actions to show per page
            purgePermissionLevel = 4; # Permission level for purge command
          };
          color = {
            primary = "#009688";
            primaryVariant = "#52c7b8";
            secondary = "#1e88e5";
            secondaryVariant = "#6ab7ff";
            light = "#c5d6f0";
          };
          actions = {
            # Blacklists - blacklisted things will not be logged in the database
            typeBlacklist = [ ]; # Blacklists action types. Ex: "block-break", "entity-kill"
            worldBlacklist = [ ]; # Blacklists worlds/dimensions. Ex: "mincraft:the_end", "minecraft:overworld"
            objectBlacklist = [ ]; # Blacklists objects (Items, Mobs, Blocks). Ex: "minecraft:cobblestone", "minecraft:blaze"
            sourceBlacklist = [ ]; # Blacklists sources. Ex: "lava", "gravity", "fire", "fall"
          };
          networking.networking = true; # allow Ledger client mod packets
          database_extensions = {
            database = "POSTGRESQL";
            url = "localhost:${builtins.toString config.services.postgresql.settings.port}/${config.services.minecraft-servers.user}";
            username = config.services.minecraft-servers.user;
            password = "";
            properties = [ ];
          };
        };
      };
    };
  };

  services.postgresql.ensureDatabases = [
    config.services.minecraft-servers.user
  ];
  services.postgresql.ensureUsers = [
    {
      name = config.services.minecraft-servers.user;
      ensureDBOwnership = true;
    }
  ];

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

  users.users.arc.extraGroups = [ "minecraft" ];
}
