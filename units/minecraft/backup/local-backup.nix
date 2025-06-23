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
        script = builtins.readFile ./before-backup.sh;
        environment = {
          DATA_PATH = dataDir;
          SOCKET_PATH = socket;
          SAVE_WAIT_TIME = "60";
          SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
        };
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
        script = builtins.readFile ./after-backup.sh;
        environment = {
          DATA_PATH = dataDir;
          SOCKET_PATH = socket;
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
        # run setup
        requires = [ "minecraft-before-local-backup-${name}.service" ];
        after = [ "minecraft-before-local-backup-${name}.service" ];
        # and cleanup
        wants = [ "minecraft-after-local-backup-${name}.service" ]; # we use wants because we want to run cleanup even on failure
        before = [ "minecraft-after-local-backup-${name}.service" ];
        # trigger webhook on failure
        onFailure = [ "notify-minecraft-backup-failed-${name}.service" ];
        serviceConfig = {
          User = config.services.minecraft-servers.user;
          Group = config.services.minecraft-servers.group;
          Type = "oneshot";
        };
        # we inline this so we can easily reference pkgs.fd
        script = ''
          BACKUP_PATH="$BACKUP_ROOT/$(date +%Y%m%d-%H%M)"
          mkdir -p "$BACKUP_PATH"
          cp --reflink=always -r "$DATA_PATH" "$BACKUP_PATH"
          # for the eventual cleanup script
          ${pkgs.fd}/bin/fd --type directory --exact-depth 1 --changed-before 1d --absolute-path --full-path "$BACKUP_ROOT" "$BACKUP_ROOT" | xargs --no-run-if-empty --verbose rm --recursive --preserve-root=all --verbose
          echo "Backup done"
        '';
        environment = {
          BACKUP_ROOT = "${config.services.minecraft-servers.dataDir}/backup/${name}";
          DATA_PATH = dataDir;
        };
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
