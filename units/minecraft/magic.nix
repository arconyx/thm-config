# Socket activation based on https://dataswamp.org/~solene/2022-08-20-on-demand-minecraft-with-systemd.html

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

  # internal port used by server
  minecraft-port = 25564;
  # public port exposed though firewall
  public-port = 25565;

  # wait 60s for a TCP socket to be available
  # to wait in the proxifier
  # idea found in http://web.archive.org/web/20240215035104/https://blog.developer.atlassian.com/docker-systemd-socket-activation/
  wait-tcp = pkgs.writeShellScriptBin "wait-tcp" ''
    for i in `seq 300`; do
      if ${pkgs.libressl.nc}/bin/nc -z 127.0.0.1 ${toString minecraft-port} > /dev/null ; then
        exit 0
      fi
      ${pkgs.busybox.out}/bin/sleep 1
    done
    exit 1
  '';

  # time in second before we could stop the server
  # this should let it time to spawn
  minimum-server-lifetime = 600;

  # script returning true if the server has to be shutdown
  # for minecraft, uses rcon to get the player list
  # skips the checks if the service started less than minimum-server-lifetime
  no-player-connected = pkgs.writeShellScriptBin "no-player-connected" ''
    servicestartsec=$(date -d "$(systemctl show --property=ActiveEnterTimestamp minecraft-server-magic.service | cut -d= -f2)" +%s)
    serviceelapsedsec=$(( $(date +%s) - servicestartsec))

    # exit if the server started less than 10 minutes ago
    if [ $serviceelapsedsec -lt ${toString minimum-server-lifetime} ]
    then
      echo "server is too young to be stopped"
      exit 1
    fi

    PLAYERS=`printf "list\n" | ${pkgs.rcon.out}/bin/rcon -m -H 127.0.0.1 -p 25575 -P ${rcon-password}`
    if echo "$PLAYERS" | grep "are 0 of a"
    then
      exit 0
    else
      exit 1
    fi
  '';

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
        openFirewall = false;
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
          server-port = minecraft-port;
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

  networking.firewall.allowedTCPPorts = [ public-port ];

  # this waits for incoming connection on public-port
  # and triggers listen-minecraft.service upon connection
  systemd.sockets.listen-minecraft = {
    enable = true;
    wantedBy = [ "sockets.target" ];
    requires = [ "network.target" ];
    after = [ "network.target" ];
    listenStreams = [ "${toString public-port}" ];
  };

  # this is triggered by a connection on TCP port public-port
  # start hook-minecraft if not running yet and wait for it to return
  # then, proxify the TCP connection to the real Minecraft port on localhost
  systemd.services.listen-minecraft = {
    enable = true;
    requires = [
      "hook-minecraft.service"
      "listen-minecraft.socket"
    ];
    after = [
      "hook-minecraft.service"
      "listen-minecraft.socket"
    ];
    script = ''
      echo "minecraft socket listener triggered"
      ${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString minecraft-port}
    '';
  };

  # this starts Minecraft is required
  # and wait for it to be available over TCP
  # to unlock listen-minecraft.service proxy
  systemd.services.hook-minecraft = {
    enable = true;
    serviceConfig.ExecStartPost = "${wait-tcp}/bin/wait-tcp";
    script = ''
      echo "minecraft hook firing"
      ${pkgs.systemd}/bin/systemctl start minecraft-server-magic.service
      ${pkgs.systemd}/bin/systemctl start stop-minecraft.timer
    '';
  };

  # create a timer running every minute
  # that runs stop-minecraft.service script
  # to check if the server needs to be stopped
  systemd.timers.stop-minecraft = {
    enable = true;
    timerConfig = {
      OnCalendar = "minutely";
      Unit = "stop-minecraft.service";
    };
    wantedBy = [ "timers.target" ];
  };

  # run the script no-player-connected
  # and if it returns true, stop the minecraft-server
  # but also the timer and the hook-minecraft service
  # to prepare a working state ready to resume the
  # server again
  systemd.services.stop-minecraft = {
    enable = true;
    serviceConfig.Type = "oneshot";
    requisite = [ "minecraft-server-magic.service" ];
    after = [ "minecraft-server-magic.service" ];
    script = ''
      if ${no-player-connected}/bin/no-player-connected
      then
        echo "stopping server"
        systemctl stop minecraft-server-magic.service
        systemctl stop hook-minecraft.service
        systemctl stop stop-minecraft.timer
      fi
    '';
  };

}
