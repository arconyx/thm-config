{
  config,
  pkgs,
  lib,
  modpack,
  ...
}:
let
  utils = import ./utils.nix { inherit config lib; };
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
  };

  services.minecraft-servers.servers = {
    magic =
      let
        mcVersion = modpack.manifest.versions.minecraft;
        fabricVersion = modpack.manifest.versions.fabric;
        serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
        socket = config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path "magic";
      in
      {
        enable = true;
        package = pkgs.fabricServers.${serverVersion}.override {
          loaderVersion = fabricVersion;
          jre_headless = pkgs.graalvmPackages.graalvm-oracle;
        };
        autoStart = true;
        operators = { };
        jvmOpts = "-Xms8G -Xmx8G -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:AllocatePrefetchStyle=3 -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:+EagerJVMCI -Dgraal.TuneInlinerExploration=1 -Djdk.graal.CompilerConfiguration=enterprise -XX:+UseG1GC -XX:MaxGCPauseMillis=130 -XX:G1NewSizePercent=28 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:+UseTransparentHugePages -XX:ConcGCThreads=6 --enable-native-access=ALL-UNNAMED";
        serverProperties = {
          gamemode = "survival";
          enable-command-block = true;
          motd = "Apply to the Hexcasting Academy today!";
          difficulty = "hard";
          allow-flight = "true";
          view-distance = 8;
          simulation-distance = 8;
          server-port = 25565;
          white-list = true;
          enforce-whitelist = true;
          spawn-protection = 0;
          initial-disabled-packs = "";
        };
        symlinks = modpack.modLinks;
        files = {
          "config" = "${modpack}/config";
          "kubejs" = "${modpack}/kubejs";
        };
        extraStopPre = ''
          echo "say Server shutdown in 60 seconds" > "${socket}" && sleep 60 || echo "Unable to send shutdown warning"
        '';
      };
  };

  systemd.services = utils.forEachServer (
    name: cfg: {
      "minecraft-server-${name}" = {
        onFailure = [ "notify-minecraft-server-failed-magic.service" ];
        serviceConfig = {
          CapabilityBoundingSet = [ "CAP_PERFMON" ]; # for spark
          TimeoutStopSec = lib.mkForce "2min 15s"; # increased to account for shutdown warning
        };
      };

      # calls webhook to report failure
      "notify-minecraft-server-failed-${name}" = {
        enable = true;
        description = "Notify on failed Minecraft server";
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = "/etc/minecraft/magic.env";
        };
        script = ''
          ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="Server crash detected. If it does not restart automatically within 10 minutes ping ArcOnyx." "$DISCORD_WEBHOOK_URL"
        '';
      };
    }
  );

  users.users.arc.extraGroups = [ "minecraft" ];
}
