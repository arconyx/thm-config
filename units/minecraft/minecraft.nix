{
  pkgs,
  lib,
  modpack,
  ...
}:
let
  mcVersion = modpack.manifest.versions.minecraft;
  fabricVersion = modpack.manifest.versions.fabric;
  serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
  graal = import ./graal/graal.nix pkgs;
in
{
  imports = [
    ./backup/backup.nix
    ./network.nix
  ];

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
      package = pkgs.fabricServers.${serverVersion}.override {
        loaderVersion = fabricVersion;
        jre_headless = graal;
      };
      autoStart = true;
      operators = {
        ArcOnyx = {
          uuid = "36322fea-3925-4ee1-a160-1f068e7cef44";
          level = 4;
          bypassesPlayerLimit = true;
        };
        Qyila = {
          uuid = "9aba3284-1e93-4e49-a8f4-73a9fbe2a3e3";
          level = 4;
        };
        Sithisilith = {
          uuid = "b4807d95-aaf5-4654-b226-a2d278a71553";
          level = 2;
        };
        FISHYNZ_ = {
          uuid = "53a2148c-0690-4aa0-b75a-2072d78a772a";
          level = 2;
        };
        SurrealThings = {
          uuid = "574f914f-f5e1-4a3d-9942-ca11b339713d";
          level = 3;
        };
      };
      jvmOpts = "-Xms8G -Xmx8G -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:AllocatePrefetchStyle=3 -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:+EagerJVMCI -Dgraal.TuneInlinerExploration=1 -Djdk.graal.CompilerConfiguration=enterprise -XX:+UseG1GC -XX:MaxGCPauseMillis=130 -XX:G1NewSizePercent=28 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:+UseTransparentHugePages -XX:ConcGCThreads=6 --enable-native-access=ALL-UNNAMED";
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
      symlinks = modpack.modLinks;
      files = {
        "config" = "${modpack}/config";
      };
    };
  };

  users.users.arc.extraGroups = [ "minecraft" ];

  # for spark
  systemd.services.minecraft-server-magic.serviceConfig.CapabilityBoundingSet = [ "CAP_PERFMON" ];
}
