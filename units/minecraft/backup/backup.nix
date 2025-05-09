{ pkgs, config, ... }:
{
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
        BACKUP_DEST = "Remote";
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        BACKUP_WARNING_TIME = "600";
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
      conflicts = [
        "restic-backups-backblaze.service"
        "minecraft-before-backup.service"
        "minecraft-after-backup.service"
      ];
      serviceConfig = {
        User = config.services.minecraft-servers.user;
        Group = config.services.minecraft-servers.group;
        Type = "oneshot";
      };
      script = builtins.readFile ./local-backup.sh;
      environment = {
        BACKUP_DEST = "Local";
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
        SERVER_NAME = "magic";
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
