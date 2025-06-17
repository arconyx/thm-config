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
    ];
    paths = [
      "/etc/minecraft"
      # /srv/minecraft already added by top level conf
    ];
  };

  systemd.services =
    let
      forEachServer =
        f: lib.concatMapAttrs (name: value: f name value) config.services.minecraft-servers.servers;
    in
    forEachServer (
      name: cfg:
      let
        socket = builtins.toString (
          config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path name
        );
      in
      lib.mkIf cfg.enable {
        restic-backups-backblaze = {
          # Shutdown server during backup
          conflicts = [ "minecraft-server-${name}.service" ];
          # If we somehow start at the same time, run the backup first
          before = [ "minecraft-server-${name}.service" ];
          # Call warning script before we run
          wants = [ "minecraft-shutdown-warning-${name}.service" ];
          after = [ "minecraft-shutdown-warning-${name}.service" ];
          # Restart server after, printing warning on failure
          onSuccess = [ "minecraft-server-${name}.service" ];
          onFailure = [
            "minecraft-server-${name}.service"
            "minecraft-remote-backup-failure-warning-${name}.service"
          ];
        };

        "minecraft-shutdown-warning-${name}" = {
          enable = true;
          description = "Warn about Minecraft server '${name}' shutdown";
          requisite = [
            "minecraft-server-${name}.service"
            "minecraft-server-${name}.socket"
          ];
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
            SOCKET_PATH = socket;
            WARNING_TIME = "600";
          };
        };

        "minecraft-remote-backup-failure-warning-${name}" = {
          enable = true;
          description = "Warn about failed remote backup of Minecraft server '${name}'";
          requires = [
            "minecraft-server-${name}.service"
            "minecraft-server-${name}.socket"
          ];
          after = [
            "minecraft-server-${name}.service"
            "minecraft-server-${name}.socket"
          ];
          serviceConfig = {
            User = config.services.minecraft-servers.user;
            Group = config.services.minecraft-servers.group;
            Type = "oneshot";
          };
          script = ''
            if [[ -p "$SOCKET_PATH" ]]; then
              echo "Attempting to send in-game notification of failed backup."
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
            SOCKET_PATH = socket;
          };
        };
      }
    );
}
