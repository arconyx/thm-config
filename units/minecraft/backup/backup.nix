{ config, lib, ... }:
let
  utils = import ./../utils.nix { inherit config lib; };
in
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

  systemd.services = utils.forEachServer (
    name: cfg:
    let
      socket = config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path name;
    in
    lib.mkIf cfg.enable {
      restic-backups-backblaze = {
        # Shutdown server during backup
        # If we somehow start at the same time, run the backup first
        before = [ "minecraft-server-${name}.service" ];
        # Restart server after, printing warning on failure
        onSuccess = [ "minecraft-server-${name}.service" ];
        onFailure = [
          "minecraft-server-${name}.service"
          "minecraft-remote-backup-failure-warning-${name}.service"
        ];
        preStart = ''
          echo "Trying to send shutdown warning for minecraft server ${name}"
          if [[ -p "${socket}" ]]; then
            echo "Server shutdown warning triggered"
            if echo "say Server will shutdown for backup in 10 minutes." > "${socket}"; then
                echo "Shutdown warning command sent successfully."
            else
                echo "Warning: Failed to send shutdown warning via socket."
            fi
            # Sleep time is 540 seconds because there is an additional 60 second delay built into server shutdown
            sleep 540
          else
              echo "Warning: Socket file '${socket}' not found or is not a socket."
              echo "Minecraft server ${name} appears to be offline or socket is not active."
              echo "Backup will proceed regardless."
          fi
          systemctl stop minecraft-server-${name}
        '';
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
          if [[ -p "${socket}" ]]; then
            echo "Attempting to send in-game notification of failed backup."
            if echo "say WARNING: Server backup failed!" > "${socket}"; then
                echo "Warning sent successfully."
            else
                echo "Warning: Failed to send backup failure warning via socket."
            fi
          else
              echo "Warning: Socket file '${socket}' not found or is not a socket."
              echo "Minecraft server appears to be offline or socket is not active."
          fi
        '';
      };
    }
  );
}
