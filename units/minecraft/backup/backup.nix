{ pkgs, config, ... }:
{
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

  # TODO: Parameterise server name
  systemd.services = {
    # trigger prep and cleanup units
    restic-backups-backblaze = {
      # restic can still run even if these fail - e.g. the server is off
      wants = [
        "minecraft-after-backup@1.service"
        "minecraft-before-backup@1.service"
      ];
    };

    # define prep unit
    # if arg is 1 then announce steps in mc chat
    # if arg is 0 then run silently
    "minecraft-before-backup@" = {
      enable = true;
      description = "Prepare for restic backup of Minecraft server";
      # if the server isn't running then these won't work and aren't required anyway
      requisite = [
        "minecraft-server-magic.service"
        "minecraft-server-magic.socket"
      ];
      # run before backups
      before = [
        "restic-backups-backblaze.service"
        "minecraft-local-backup.service"
      ];
      # make sure the server has started before we run
      after = [
        "minecraft-server-magic.service"
        "minecraft-server-magic.socket"
      ];
      serviceConfig = {
        User = config.services.minecraft-servers.user;
        Group = config.services.minecraft-servers.group;
        Type = "oneshot";
      };
      script = builtins.readFile ./before-backup.sh;
      environment = {
        ANNOUNCE = "%i"; # @arg goes here
        BACKUP_DEST = "Remote";
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        SAVE_WAIT_TIME = "60";
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
      };
    };

    # define cleanup unit
    # same arg handling as above
    "minecraft-after-backup@" = {
      enable = true;
      description = "Cleanup after restic backup of Minecraft server";
      # server needs to be running
      requisite = [
        "minecraft-server-magic.service"
        "minecraft-server-magic.socket"
      ];
      # only run after backups
      after = [
        "restic-backups-backblaze.service"
        "minecraft-local-backup.service"
      ];
      serviceConfig = {
        User = config.services.minecraft-servers.user;
        Group = config.services.minecraft-servers.group;
        Type = "oneshot";
      };
      script = builtins.readFile ./after-backup.sh;
      environment = {
        ANNOUNCE = "%i"; # @arg goes here
        BACKUP_DEST = "Remote";
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
      };
    };

    # backup to a local folder
    minecraft-local-backup = {
      enable = true;
      description = "Backup Minecraft server to a local folder";
      # only while the server is running because otherwise things aren't changing and it should be fine
      requisite = [
        "minecraft-server-magic.service"
        "minecraft-server-magic.socket"
      ];
      # don't run while other backups are running
      conflicts = [
        "restic-backups-backblaze.service"
        "minecraft-after-backup@1.service"
        "minecraft-before-backup@1.service"
      ];
      # run setup
      requires = [ "minecraft-before-backup@0.service" ];
      after = [ "minecraft-before-backup@0.service" ];
      # and cleanup
      wants = [ "minecraft-after-backup@0.service" ]; # we use wants because we want to run cleanup even on failure
      before = [ "minecraft-after-backup@0.service" ];
      # trigger webhook on failure
      unitConfig.OnFailure = "notify-minecraft-backup-failed.service";
      serviceConfig = {
        User = config.services.minecraft-servers.user;
        Group = config.services.minecraft-servers.group;
        Type = "oneshot";
      };
      # we inline this so we can easily reference pkgs.fd
      script = ''
        BACKUP_PATH="/srv/minecraft/backup/$(date --iso-8601=minutes)"
        mkdir -p "$BACKUP_PATH"
        cp --reflink=always -r "$DATA_PATH" "$BACKUP_PATH"
        # for the eventual cleanup script
        ${pkgs.fd}/bin/fd --type directory --exact-depth 1 --changed-before 1d --absolute-path --full-path '/srv/minecraft/backup/' /srv/minecraft/backup
        echo "Backup done"
      '';
      environment = {
        ANNOUNCE = "0";
        BACKUP_DEST = "Local";
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
        SAVE_WAIT_TIME = "60";
      };
    };

    # calls webhook to report failure
    notify-minecraft-backup-failed = {
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
  };

  systemd.timers.minecraft-local-backup = {
    enable = true;
    description = "Run local backup of Minecraft server regularly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "00/4:00";
      Unit = "minecraft-local-backup.service";
    };
  };
}
