{
  config,
  pkgs,
  ...
}:
let
  credentialsDir = "/etc/backups";
in
{
  services.restic.backups.backblaze = {
    environmentFile = "${credentialsDir}/backblaze.env";
    passwordFile = "${credentialsDir}/backblaze.password";

    extraBackupArgs = [
      "--exclude-caches"
      "--skip-if-unchanged"
      "--verbose"
      "--no-scan"
      "--exclude-if-present .nobackup"
    ];

    checkOpts = [
      "--with-cache"
      "--read-data-subset=1%"
    ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 3"
      "--keep-monthly 6"
      "--keep-yearly 3"
      "--group-by host"
    ];

    paths = [ "/var/lib/nixos" ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "5h";
      FixedRandomDelay = true;
    };
  };

  systemd.services = {
    notify-backup-failed = {
      enable = true;
      description = "Notify on failed backup";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "${credentialsDir}/webhooks.env";
      };
      script = ''
        ${pkgs.curl}/bin/curl --silent -F username=${config.networking.hostName} -F content="Backup failed" "$DISCORD_URL"
      '';
    };

    notify-backup-succeeded = {
      enable = true;
      description = "Ping uptime monitor with successful backup";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "${credentialsDir}/webhooks.env";
      };
      script = ''
        ${pkgs.curl}/bin/curl --silent "$UPTIME_URL"
      '';
    };

    restic-backups-backblaze = {
      onSuccess = [ "notify-backup-succeeded.service" ];
      onFailure = [ "notify-backup-failed.service" ];
    };
  };
}
