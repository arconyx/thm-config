{
  config,
  pkgs,
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
      dataDir =
        builtins.toString
          config.systemd.services."minecraft-server-${name}".serviceConfig.WorkingDirectory;
      backupRoot = "${config.services.minecraft-servers.dataDir}/backup/${name}";
    in
    lib.mkIf cfg.enable {
      "minecraft-before-local-backup-${name}" = {
        enable = true;
        description = "Prepare for local backup of Minecraft server";
        # if the server isn't running then these won't work and aren't required anyway
        requisite = [
          "minecraft-server-${name}.service"
          "minecraft-server-${name}.socket"
        ];
        # run before backups
        before = [
          "minecraft-local-backup-${name}.service"
        ];
        # make sure the server has started before we run
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
          # Check if the socket path exists and is a socket file
          if [[ -p "${socket}" ]]; then
              echo "Minecraft server socket found. Proceeding with save commands."

              # Send the 'save-off' command to the server via the socket
              echo "Sending 'save-off' command..."
              if echo "save-off" > "${socket}"; then
                  echo "tell @a Local backup started. Autosave disabled." > "${socket}"
                  echo "'save-off' command sent successfully."
              else
                  echo "Warning: Failed to send 'save-off' command via socket."
                  echo "say Backup error: Unable to pause autosave" > "${socket}"
                  # Continue execution even if sending fails, server might be shutting down
              fi

              # Add a small delay to ensure the server processes the save-off command
              sleep 1

              # Send the 'save-all' command to the server via the socket
              echo "Sending 'save-all' command..."
              if echo "save-all" > "${socket}"; then
                   echo "'save-all' command sent successfully."
              else
                  echo "Warning: Failed to send 'save-all' command via socket."
                  echo "say Backup error: Unable to force save" > "${socket}"
                  # Continue execution even if sending fails
              fi

              # Add a delay to allow the server to complete the manual save before backup starts
              echo "Waiting $SAVE_WAIT_TIME seconds for the server to complete saving (if online)..."
              sleep "$SAVE_WAIT_TIME"

          else
              echo "Warning: Socket file '${socket}' not found or is not a socket."
              echo "Minecraft server appears to be offline or socket is not active."
              echo "Skipping save commands. Backup will proceed without pausing server saves."
          fi


          if "${pkgs.sqlite}/bin/sqlite3" "${dataDir}/world/ledger.sqlite" "VACUUM INTO '${dataDir}/ledger_backup.sqlite'"; then
              echo "Exported ledger database"
          else
              echo "Warning: Unable to export ledger database"
              echo "say Backup error: Unable to export ledger" > "${socket}"
          fi

          echo "Minecraft Server Pre-Backup Script Finished."
        '';
        environment = {
          SAVE_WAIT_TIME = "60";
        };
      };

      # backup to a local folder
      "minecraft-local-backup-${name}" = {
        enable = true;
        description = "Backup Minecraft server to a local folder";
        # only while the server is running because otherwise things aren't changing and it should be fine
        requisite = [
          "minecraft-server-${name}.service"
          "minecraft-server-${name}.socket"
        ];
        # don't run while other backups are running
        conflicts = [ "restic-backups-backblaze.service" ];
        # run setup and cleanup
        wants = [
          "minecraft-after-local-backup-${name}.service"
          "minecraft-before-local-backup-${name}.service"
        ];
        after = [ "minecraft-before-local-backup-${name}.service" ];
        before = [ "minecraft-after-local-backup-${name}.service" ];
        # trigger webhook on failure
        onFailure = [ "notify-minecraft-backup-failed-${name}.service" ];
        serviceConfig = {
          User = config.services.minecraft-servers.user;
          Group = config.services.minecraft-servers.group;
          Type = "oneshot";
        };
        script = ''
          BACKUP_PATH="${backupRoot}/$(date +%Y%m%d-%H%M)"
          mkdir -p "$BACKUP_PATH"
          cp --reflink=always -r "${dataDir}" "$BACKUP_PATH"
          # for the eventual cleanup script
          echo "Backup done"
        '';
      };

      "minecraft-after-local-backup-${name}" = {
        enable = true;
        description = "Cleanup after local backup of Minecraft server";
        # server needs to be running
        requisite = [
          "minecraft-server-${name}.service"
          "minecraft-server-${name}.socket"
        ];
        # only run after backups
        after = [
          "minecraft-local-backup-${name}.service"
        ];
        serviceConfig = {
          User = config.services.minecraft-servers.user;
          Group = config.services.minecraft-servers.group;
          Type = "oneshot";
        };
        script = ''
          # Check if the socket path exists and is a socket file
          if [[ -p "${socket}" ]]; then
              echo "Minecraft server socket found. Proceeding with save-on command."

              # Send the 'save-on' command to the server via the socket
              echo "Sending 'save-on' command..."
              if echo "save-on" > "${socket}"; then
                  echo "tell @a Local backup finished. Autosave enabled." > "${socket}"
                  echo "'save-on' command sent successfully. Autosave re-enabled."
              else
                  echo "Warning: Failed to send 'save-on' command via socket."
                  echo "say Backup error: Unable to resume autosave" > "${socket}"
                  # Continue execution even if sending fails
              fi

          else
              echo "Warning: Socket file '${socket}' not found or is not a socket."
              echo "Minecraft server appears to be offline or socket is not active."
              echo "Skipping save-on command."
          fi

          if rm "$${dataDir}/ledger_backup.sqlite"; then
              echo "Removed ledger backup db"
          else
              echo "Warning: Unable to cleanup ledger database"
              echo "say Backup error: Unable to cleanup ledger export" > "${socket}"
          fi

          echo "Cleaning old backups"
          ${pkgs.fd}/bin/fd --type directory --exact-depth 1 --changed-before 1d --absolute-path --full-path "${backupRoot}" "${backupRoot}" | xargs --no-run-if-empty --verbose rm --recursive --preserve-root=all --verbose
          echo "Cleanup done"
        '';
      };

      # calls webhook to report failure
      "notify-minecraft-backup-failed-${name}" = {
        enable = true;
        description = "Notify on failed local Minecraft backup";
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = "/etc/backblaze/sentinel.env";
        };
        script = ''
          ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="Local Minecraft backup failed" "$WEBHOOK_URL"
        '';
      };
    }
  );

  systemd.timers = utils.forEachServer (
    name: cfg: {
      "minecraft-local-backup-${name}" = {
        enable = true;
        description = "Run local backup of Minecraft server regularly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "00/4:00";
          Unit = "minecraft-local-backup-${name}.service";
        };
      };
    }
  );
}
