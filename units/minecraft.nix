{ pkgs, ... }:
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
    servers.fabric = {
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
        enable-command-block = "false";
        motd = "Test server";
        difficulty = "hard";
        allow-flight = "true";
        view-distance = 16;
        server-port = 25565;
        white-list = true;
        enforce-whitelist = true;
        spawn-protection = 0;
      };
    };
  };
}
