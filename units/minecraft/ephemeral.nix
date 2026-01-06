{
  config,
  lib,
  pkgs,
  ...
}:
let
  mcCfg = config.thm.services.minecraft;
  ephemeralServers = lib.filterAttrs (_: cfg: cfg.enable && !cfg.alwaysOn) mcCfg.servers;
  useEphemeral = mcCfg.enable && ephemeralServers != [ ];
in
{
  config = lib.mkIf useEphemeral {
    # allow starting servers with a webhook
    services.webhook =
      let
        ephemeralServices = lib.mapAttrsToList (_: cfg: cfg.serviceName) ephemeralServers;
      in
      {
        enable = useEphemeral;
        # bind to loopback only
        # we're not opening the firewall, but better safe
        ip = "127.0.0.1";
        verbose = true;
        hooks = lib.concatMapAttrs (
          name: cfg:
          let
            msg-discord = msg: ''
              ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="[${name}] ${msg}" "$DISCORD_WEBHOOK_URL"
            '';
            start-server = pkgs.writeShellScript "start-minecraft-server-from-webhook" ''
              source ${mcCfg.environmentFile}
              if systemctl is-active --quiet restic-backups-backblaze.service; then
                ${msg-discord "Backup in progress. Please wait until it is finished to start the server."}
              elif systemctl is-active --quiet ${lib.concatStringsSep " " (lib.remove cfg.serviceName ephemeralServices)}; then
                ${msg-discord "Another server is running. Please wait until it is finished to start the server."}
              elif systemctl is-active --quiet ${cfg.serviceName}; then
                ${msg-discord "Server is already running."}
              else
                systemctl start ${cfg.serviceName}
              fi
            '';
          in
          {
            "minecraft-${name}" = {
              id = "start-mc-${name}";
              execute-command = "${start-server}";
            };
          }
        ) ephemeralServers;
      };
    # Use polkit to give the webhooks user permission to start the service
    security.polkit = {
      enable = true;
      extraConfig = lib.concatLines (
        [ "/* Allow webhooks to launch Minecraft */" ]
        ++ (lib.mapAttrsToList (name: cfg: ''
          polkit.addRule(function(action, subject) {
            if (
              action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "${cfg.serviceName}" &&
              subject.user == "${config.services.webhook.user}" &&
              action.lookup("verb") == "start"
            ) {
              return polkit.Result.YES;
            }
          });
        '') ephemeralServers)
      );
    };

    # Create a timer runs stop-minecraft.service script on a regular
    # basis to check if the server needs to be stopped
    systemd.timers = lib.concatMapAttrs (name: cfg: {
      "stop-minecraft-${name}" = {
        enable = true;
        timerConfig = {
          # startup when the timer has been active for 10 minutes
          OnActiveSec = "10min";
          # run when the associated service has been stopped for 10 minutes
          OnUnitInactiveSec = "10min";
        };
        wantedBy = [ cfg.serviceName ];
        after = [ cfg.serviceName ];
        partOf = [ cfg.serviceName ];
      };
    }) ephemeralServers;

    systemd.services = {
      # access to env file for discord token
      webhook.serviceConfig = {
        SupplementaryGroups = [ "minecraft" ];
      };
    }
    // (lib.concatMapAttrs (name: cfg: {
      "minecraft-server-${name}".wants = lib.mkIf mcCfg.proxy.enable [ "gate.service" ];

      # if no player is connected wait a minute
      # if still no players, shutdown the server
      "stop-minecraft-${name}" = {
        enable = true;
        serviceConfig.Type = "oneshot";
        script =
          let
            rcon = "${pkgs.rcon}/bin/rcon -m -H 127.0.0.1 -p ${builtins.toString cfg.rcon-port} -P ${cfg.rcon-password}";
            wait_seconds = "60";
          in
          ''
            PLAYERS=$(printf "list\n" | ${rcon})
            if echo "$PLAYERS" | grep "are 0 of a"
            then
              echo "no players online, checking again in a ${wait_seconds}s"
              ${pkgs.coreutils}/bin/sleep ${wait_seconds}
              STILL_PLAYERS=$(printf "list\n" | ${rcon})
              if echo "$STILL_PLAYERS" | grep "are 0 of a"
              then
                echo "stopping server: no players online"
                systemctl stop ${cfg.serviceName}
                systemctl stop stop-minecraft-${name}.timer
              else
                echo "player has come online, shutdown cancelled"
              fi
            else
              echo "players online"
              exit 0
            fi
          '';
      };
    }) ephemeralServers);
  };
}
