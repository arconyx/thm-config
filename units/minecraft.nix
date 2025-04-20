{ pkgs, lib, ... }:
let
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/ArcOnyx/thm-modpack/raw/85f4577d799d03885c5a2a6aa079ab93f92252e7/pack.toml";
    packHash = "sha256-PUeEO9o6LXTVlqqBxOA4DQsbaRnLjFAyLEdt43Cb01Y=";
    manifestHash = "sha256:0rifs9i64kjv3aiiblnjkv64bix38z46y6znspc54pgrqh9v2piv";
  };
  mcVersion = modpack.manifest.versions.minecraft;
  fabricVersion = modpack.manifest.versions.fabric;
  serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
in
{
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    dataDir = "/srv/minecraft";
    environmentFile = "/etc/minecraft/magic.env";
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
        initial-disabled-packs = "";
      };
      symlinks = {
        "mods" = "${modpack}/mods";
      };
      files = {
        "config" = "${modpack}/config";
      };
    };
  };

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

  # additional backup paths
  services.restic.backups.backblaze.paths = [
    "/etc/minecraft"
  ];
}
