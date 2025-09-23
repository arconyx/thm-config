# Socket activation based on https://dataswamp.org/~solene/2022-08-20-on-demand-minecraft-with-systemd.html
# Then heavily modified because something keeps triggering the socket

{
  pkgs,
  thm-modpack,
  config,
  lib,
  ...
}:
let
  modpack = thm-modpack.packages.${config.nixpkgs.hostPlatform.system}.default;
  # plaintext in the store and on github
  # but we keep the port closed so this should only be accessible from localhost
  rcon-password = "3489trawo5ATpfhaQEQr"; # pragma: allowlist secret
in
{
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
        autoStart = false;
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
          enable-rcon = true;
          "rcon.password" = rcon-password;
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

  # create a timer runs stop-minecraft.service script on a regular
  # basis to check if the server needs to be stopped
  systemd.timers.stop-minecraft = {
    enable = true;
    timerConfig = {
      OnActiveSec = "10min";
      OnUnitInactiveSec = "10min";
      Unit = "stop-minecraft.service";
    };
    wantedBy = [ "minecraft-server-magic.service" ];
    after = [ "minecraft-server-magic.service" ];
    partOf = [ "minecraft-server-magic.service" ];
  };

  # if no player is connected wait a minute
  # if still no players, shutdown the server
  systemd.services.stop-minecraft = {
    enable = true;
    serviceConfig.Type = "oneshot";
    script = ''
      PLAYERS=$(printf "list\n" | ${pkgs.rcon}/bin/rcon -m -H 127.0.0.1 -p 25575 -P ${rcon-password})
      if echo "$PLAYERS" | grep "are 0 of a"
      then
        echo "no players online, checking again in a minute"
        ${pkgs.coreutils}/bin/sleep 60
        STILL_PLAYERS=$(printf "list\n" | ${pkgs.rcon}/bin/rcon -m -H 127.0.0.1 -p 25575 -P ${rcon-password})
        if echo "$STILL_PLAYERS" | grep "are 0 of a"
        then
          echo "stopping server: no players online"
          systemctl stop minecraft-server-magic.service
          systemctl stop stop-minecraft.timer
        else
          echo "player has come online, shutdown cancelled"
        fi
      else
        exit 1
      fi
    '';
  };
}
