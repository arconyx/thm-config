{ pkgs, config, ... }:
{
  # additional backup paths
  services.restic.backups.backblaze = {
    exclude = [
      "DistantHorizons.sqlite"
      "DistantHorizons.sqlite-shm"
      "DistantHorizons.sqlite-wal"
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
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        BACKUP_WARNING_TIME = "600";
        SAVE_WAIT_TIME = "60";
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
      };
    };

    minecraft-after-backup = {
      enable = true;
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
        DATA_PATH = config.systemd.services.minecraft-server-magic.serviceConfig.WorkingDirectory;
        SOCKET_PATH = "/run/minecraft/magic.stdin"; # trying to reference the config path failed for some reason
        SQLITE_PATH = "${pkgs.sqlite}/bin/sqlite3";
      };
    };

  };
}
