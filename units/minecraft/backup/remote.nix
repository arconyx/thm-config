{
  pkgs,
  config,
  lib,
  ...
}:
let
  utils = import ./../utils.nix { inherit config lib; };
in
{
  systemd.services = utils.forEachServer (
    name: cfg:
    let
      socket = config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path name;
    in
    lib.mkIf cfg.enable {
      restic-backups-backblaze = {
        # Shutdown server during backup
        # If we somehow start at the same time, run the backup first
        before = [
          "minecraft-server-${name}.service"
          "minecraft-remote-backup-done-notif-${name}.service"
        ];
        wants = [ "minecraft-remote-backup-done-notif-${name}.service" ];
        preStart = ''
          echo "Trying to send shutdown warning for minecraft server ${name}"
          if [[ -p "${socket}" ]]; then
            echo "Server shutdown warning triggered"
            if echo "say Server will shutdown for backup in 10 minutes. Please wait for the backup done notification in Discord before restarting it." > "${socket}"; then
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

      "minecraft-remote-backup-done-notif-${name}" = {
        enable = true;
        description = "Notify Discord about finished backup of Minecraft server '${name}'";
        serviceConfig.EnvironmentFile = config.services.minecraft-servers.environmentFile;
        script = ''
          ${pkgs.curl}/bin/curl --silent -F username=${config.networking.hostName} -F content="Backup done." "$DISCORD_WEBHOOK_URL"
        '';
      };

    }
  );
}
