{ pkgs, lib, ... }:
let
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/ArcOnyx/thm-modpack/raw/ff4c93cd6099ebc5d61e51dd10f6e7b2293911d3/pack.toml";
    packHash = "sha256-hWyQ3d6NPKfxiHVccofJWKrNDj7m+anXYYMKCcffNy0=";
    manifestHash = "sha256:0d3zbaqb9qh3ibd3fs0chmih6xb542kc9l3l8pai9cmn8g824dzn";
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
}
