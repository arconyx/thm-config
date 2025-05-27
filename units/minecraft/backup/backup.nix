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
    minecraft-before-backup = {
      enable = true;
      description = "Prepare for restic backup of Minecraft server";
      requisite = [
        "minecraft-server-magic.service"
        "minecraft-server-magic.socket"
      ];
      wantedBy = [ "restic-backups-backblaze.service" ];
      before = [ "restic-backups-backblaze.service" ];
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
        ANNOUNCE = "1";
        BACKUP_DEST = "Remote";
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        SAVE_WAIT_TIME = "60";
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
      };
    };

    minecraft-after-backup = {
      enable = true;
      description = "Cleanup after restic backup of Minecraft server";
      requisite = [
        "minecraft-server-magic.service"
        "minecraft-server-magic.socket"
      ];
      wantedBy = [ "restic-backups-backblaze.service" ];
      after = [ "restic-backups-backblaze.service" ];
      serviceConfig = {
        User = config.services.minecraft-servers.user;
        Group = config.services.minecraft-servers.group;
        Type = "oneshot";
      };
      script = builtins.readFile ./after-backup.sh;
      environment = {
        ANNOUNCE = "1";
        BACKUP_DEST = "Remote";
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
      };
    };

    minecraft-local-backup = {
      enable = true;
      description = "Backup Minecraft server to a local folder";
      requisite = [
        "minecraft-server-magic.service"
        "minecraft-server-magic.socket"
      ];
      conflicts = [ "restic-backups-backblaze.service" ];
      requires = [ "minecraft-before-backup.service" ];
      wants = [ "minecraft-after-backup.service" ]; # we use wants because we want to run cleanup even on failure
      after = [ "minecraft-before-backup.service" ];
      before = [ "minecraft-after-backup.service" ];
      serviceConfig = {
        User = config.services.minecraft-servers.user;
        Group = config.services.minecraft-servers.group;
        Type = "oneshot";
      };
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
