{ config, lib, ... }:
{
  imports = [ ./local-backup.nix ];

  # additional backup paths
  services.restic.backups.backblaze = {
    exclude = [
      "DistantHorizons.sqlite"
      "DistantHorizons.sqlite-shm"
      "DistantHorizons.sqlite-wal"
      "/srv/minecraft/backup" # don't want to waste storage backing up the local backups
      "/srv/minecraft/magic/bluemap/" # this is basically a cache
    ];
    paths = [
      "/etc/minecraft"
      # /srv/minecraft already added by top level conf
    ];
  };

  # TODO: Dynamically detect active servers
  systemd.services =
    let
      server-name = "magic";
    in
    lib.mkIf config.services.minecraft-servers.servers.${server-name}.enable {
      restic-backups-backblaze = {
        conflicts = [ "minecraft-server-${server-name}.service" ];
        before = [ "minecraft-server-${server-name}.service" ];
        onSuccess = [ "minecraft-server-${server-name}.service" ];
        onFailure = [ "minecraft-remote-backup-failure-warning.service" ];
      };

      minecraft-shutdown-warning = {
        enable = true;
        description = "Warn about Minecraft server '${server-name}' shutdown";
        requisite = [
          "minecraft-server-magic.service"
          "minecraft-server-magic.socket"
        ];
        wantedBy = [ "restic-backups-backblaze.service" ];
        before = [ "restic-backups-backblaze.service" ];
        serviceConfig = {
          User = config.services.minecraft-servers.user;
          Group = config.services.minecraft-servers.group;
          Type = "oneshot";
        };
        script = ''
          if [[ -p "$SOCKET_PATH" ]]; then
            echo "Server shutdown warning triggered"
            if echo "say Server will shutdown for backup in $WARNING_TIME seconds." > "$SOCKET_PATH"; then
                echo "Shutdown warning command sent successfully."
            else
                echo "Warning: Failed to send shutdown warning via socket."
            fi
            sleep "$WARNING_TIME"
          else
              echo "Warning: Socket file '$SOCKET_PATH' not found or is not a socket."
              echo "Minecraft server appears to be offline or socket is not active."
              echo "Backup will proceed regardless."
          fi
        '';
        environment = {
          SOCKET_PATH = "/run/minecraft/${server-name}.stdin"; # trying to reference the config path failed for some reason
          WARNING_TIME = "600";
        };
      };

      minecraft-remote-backup-failure-warning = {
        enable = true;
        description = "Warn about failed remote backup of Minecraft server '${server-name}'";
        wants = [
          "minecraft-server-magic.service"
          "minecraft-server-magic.socket"
        ];
        after = [
          "minecraft-server-magic.service"
          "minecraft-server-magic.socket"
        ];
        serviceConfig = {
          User = config.services.minecraft-servers.user;
          Group = config.services.minecraft-servers.group;
          Type = "oneshot";
        };
        script = ''
          if [[ -p "$SOCKET_PATH" ]]; then
            echo "Attempting to send ingame notification of failed backup."
            if echo "WARNING: Server backup failed!" > "$SOCKET_PATH"; then
                echo "Warning sent successfully."
            else
                echo "Warning: Failed to send backup failure warning via socket."
            fi
          else
              echo "Warning: Socket file '$SOCKET_PATH' not found or is not a socket."
              echo "Minecraft server appears to be offline or socket is not active."
          fi
        '';
        environment = {
          SOCKET_PATH = "/run/minecraft/${server-name}.stdin"; # trying to reference the config path failed for some reason
        };
      };
    };
}
