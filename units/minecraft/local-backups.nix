{
  config,
  pkgs,
  lib,
  ...
}:
let
  mcCfg = config.thm.services.minecraft;
  servers = lib.filterAttrs (_: cfg: cfg.enable) mcCfg.servers;
in
{
  systemd.services = lib.concatMapAttrs (
    name: cfg:
    let
      socket = config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path name;
      dataDir = config.systemd.services."minecraft-server-${name}".serviceConfig.WorkingDirectory;
      backupRoot = "${config.services.minecraft-servers.dataDir}/backup/${name}";
    in
    {
      # backup to a local folder
      "minecraft-local-backup-${name}" = {
        enable = true;
        description = "Backup Minecraft server to a local folder";
        conflicts = [ "restic-backups-backblaze.service" ];
        before = [ cfg.serviceName ];
        onFailure = [ "notify-minecraft-backup-failed-${name}.service" ];
        serviceConfig = {
          User = config.services.minecraft-servers.user;
          Group = config.services.minecraft-servers.group;
          Type = "oneshot";
        };
        environment = {
          SAVE_WAIT_TIME = "60";
        };
        script = ''
          # setup
          if [[ -p "${socket}" ]]; then
            if echo "save-off" > "${socket}"; then
              echo "tell @a Local backup started. Autosave disabled." > "${socket}"
              echo "'save-off' command sent successfully."
            else
              echo "Warning: Failed to send 'save-off' command via socket."
              echo "say Backup error: Unable to pause autosave" > "${socket}"
            fi
            # Add a small delay to ensure the server processes the save-off command
            sleep 1
            # Send the 'save-all' command to the server via the socket
            echo "Sending 'save-all' command..."
            if echo "save-all" > "${socket}"; then
              echo "'save-all' command sent successfully."

              # Add a delay to allow the server to complete the manual save before backup starts
              echo "Waiting $SAVE_WAIT_TIME seconds for the server to complete saving (if online)..."
              sleep "$SAVE_WAIT_TIME"
            else
              echo "Warning: Failed to send 'save-all' command via socket."
              echo "say Backup error: Unable to force save" > "${socket}"
            fi
          else
              echo "Socket not available, skipping save commands. Backup will proceed without pausing server saves."
          fi

          if [-f "${dataDir}/world/ledger.sqlite" ]; then
            if "${pkgs.sqlite}/bin/sqlite3" "${dataDir}/world/ledger.sqlite" "VACUUM INTO '${dataDir}/ledger_backup.sqlite'"; then
              echo "Exported ledger database"
            else
              echo "Warning: Unable to export ledger database"
              echo "say Backup error: Unable to export ledger" > "${socket}"
            fi
          fi

          # actual backup
          BACKUP_PATH="${backupRoot}/$(date +%Y%m%d-%H%M)"
          mkdir -p "$BACKUP_PATH"
          cp --reflink=always -r "${dataDir}" "$BACKUP_PATH"
          echo "Backup done"

          # cleanup
          if [[ -p "${socket}" ]]; then
            if echo "save-on" > "${socket}"; then
              echo "tell @a Local backup finished. Autosave enabled." > "${socket}"
              echo "'save-on' command sent successfully. Autosave re-enabled."
            else
              echo "Warning: Failed to send 'save-on' command via socket."
              echo "say Backup error: Unable to resume autosave" > "${socket}"
            fi
          else
            echo "Socket not found, skipping save-on"
          fi

          if [-f "${dataDir}/ledger_backup.sqlite"]; then
            if rm "${dataDir}/ledger_backup.sqlite"; then
              echo "Removed ledger backup db"
            else
              echo "Warning: Unable to cleanup ledger database"
              echo "say Backup error: Unable to cleanup ledger export" > "${socket}"
            fi
          fi

          echo "Cleaning old backups"
          ${pkgs.fd}/bin/fd --type directory --exact-depth 1 --changed-before 1d --absolute-path --full-path "${backupRoot}" "${backupRoot}" | xargs --no-run-if-empty rm --recursive --preserve-root=all
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
          ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="[${name}] Local Minecraft backup failed" "$WEBHOOK_URL"
        '';
      };
    }
  ) servers;

  systemd.timers = lib.concatMapAttrs (
    name: cfg: {
      "minecraft-local-backup-${name}" = {
        enable = true;
        description = "Run local backup of Minecraft server regularly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "00/4:00";
          RandomizedDelaySec = "30min";
          Unit = "minecraft-local-backup-${name}.service";
        };
      };
    }
  );
}
