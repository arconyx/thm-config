{ pkgs, ... }:
let
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/ArcOnyx/thm-modpack/raw/edff699f52c89d8820ed31afc79c88bf7224e79f/pack.toml";
    packHash = "sha256-Nc2VwAeYa687btVgaQdHAmYel3pkBUmOBjock8/Z7aI=";
  };
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
      package = pkgs.fabricServers.fabric-1_20_1;
      autoStart = true;
      operators.ArcOnyx = {
        uuid = "36322fea-3925-4ee1-a160-1f068e7cef44";
        level = 4;
        bypassesPlayerLimit = true;
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
