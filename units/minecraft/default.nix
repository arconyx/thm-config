{
  config,
  pkgs,
  lib,
  ...
}:
let
  utils = import ./utils.nix { inherit config lib; };
in
{
  imports = [
    ./backup
    ./network.nix

    ./magic.nix
  ];

  arcworks.services.backups.global = {
    exclude = [
      # Distant horizons files can be regenerated
      "DistantHorizons.sqlite"
      "DistantHorizons.sqlite-shm"
      "DistantHorizons.sqlite-wal"
      "/srv/minecraft/backup" # don't want to waste storage backing up the local backups
    ];
    paths = [
      "/etc/minecraft"
      # /srv/minecraft already added by top level conf
    ];
  };

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

  systemd.services = utils.forEachServer (
    name: cfg: {
      "minecraft-server-${name}" = {
        onFailure = [ "notify-minecraft-server-failed-${name}.service" ];
        serviceConfig = {
          CapabilityBoundingSet = [ "CAP_PERFMON" ]; # for spark
          TimeoutStopSec = lib.mkForce "2min 15s"; # increased to account for shutdown warning
        };
      };

      # calls Discord webhook to report failure
      "notify-minecraft-server-failed-${name}" = {
        enable = true;
        description = "Notify on failed Minecraft server";
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.services.minecraft-servers.environmentFile;
        };
        script = ''
          ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="Server crash detected. If it does not restart automatically within 10 minutes ping ArcOnyx." "$DISCORD_WEBHOOK_URL"
        '';
      };

      # notify Discord on startup
      "notify-minecraft-server-start-${name}" = {
        enable = true;
        description = "Notify on Minecraft server startup";
        wantedBy = [ "minecraft-server-${name}.service" ];
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.services.minecraft-servers.environmentFile;
        };
        script = ''
          ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="Raising the server from the dead." "$DISCORD_WEBHOOK_URL"
        '';
      };

      "notify-minecraft-server-unavailable-${name}" = {
        enable = true;
        description = "Notify that the Minecraft server is temporarily unavailable";
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.services.minecraft-servers.environmentFile;
        };
        script = ''
          ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="The Minecraft server is unavailable right now because Hive is being used to host a Space Engineers server. Blame Rev. Normal service will be resumed by 10 December. Maybe. Congratulations on choosing the worst possible time to try revive the server." "$DISCORD_WEBHOOK_URL"
        '';
      };
    }
  );

  users.users.arc.extraGroups = [ "minecraft" ];
}
