{ pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    enableTCPIP = false;
    checkConfig = true;
  };

  services.restic.backups.backblaze = {
    backupPrepareCommand = ''/run/wrappers/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dumpall -U postgres --clean -w -f /tmp/postgres_backup.sql'';
    backupCleanupCommand = ''rm /tmp/postgres_backup.sql'';
    paths = [
      "/tmp/postgres_backup.sql"
    ];
  };
}
