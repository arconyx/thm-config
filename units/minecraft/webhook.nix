{
  pkgs,
  config,
  lib,
  ...
}:
let
  utils = import ./utils.nix { inherit config lib; };
in
{
  # Register a webhook to start the minecraft server
  services.webhook = {
    enable = true;
    # bind to loopback only
    # we're not opening the firewall, but better safe
    ip = "127.0.0.1";
    verbose = true;
    hooks = utils.forEachServer (
      name: cfg: {
        "minecraft-${name}" = {
          id = "start-mc-${name}";
          execute-command = "${pkgs.systemd}/bin/systemctl";
          pass-arguments-to-command = [
            {
              source = "string";
              name = "start";
            }
            {
              source = "string";
              name = "minecraft-server-${name}.service";
            }
          ];
        };
      }
    );
  };

  # Use polkit to give the webhooks user permission to start the service
  security.polkit = {
    enable = true;
    extraConfig = lib.concatLines (
      utils.forEachServerName (name: ''
        /* Allow webhooks to launch Minecraft */
        polkit.addRule(function(action, subject) {
          if (
            action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "minecraft-server-${name}.service" &&
            subject.user == "${config.services.webhook.user}" &&
            action.lookup("verb") == "start"
          ) {
            return polkit.Result.YES;
          }
        });
      '')
    );
  };

  # Create a timer runs stop-minecraft.service script on a regular
  # basis to check if the server needs to be stopped
  systemd.timers = utils.forEachServer (
    name: cfg:
    let
      serviceName = "minecraft-servers-${name}.service";
    in
    {
      "stop-minecraft-${name}" = {
        enable = true;
        timerConfig = {
          OnActiveSec = "10min";
          OnUnitInactiveSec = "10min";
          Unit = "stop-minecraft.service";
        };
        wantedBy = [ serviceName ];
        after = [ serviceName ];
        partOf = [ serviceName ];
      };
    }
  );

  # if no player is connected wait a minute
  # if still no players, shutdown the server
  systemd.services = utils.forEachServer (
    name: cfg: {
      "stop-minecraft-${name}" =
        let
          rcon-password = cfg.serverProperties."rcon.password";
        in
        {
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
  );
}
