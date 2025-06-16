{ pkgs, config, ... }:

{
  services.restic.backups.backblaze = {
    repository = "s3:https://s3.us-west-004.backblazeb2.com/thm-restic-backup-bucket";
    # Environment file contains
    # AWS_ACCESS_KEY_ID=unquotedIdString
    # AWS_SECRET_ACCESS_KEY=unquotedKeyString
    environmentFile = "/etc/backblaze/backblaze.env";
    # Contains only the backups passphrase, unquoted
    passwordFile = "/etc/backblaze/backblaze.passphrase";

    initialize = true;
    inhibitsSleep = true;

    paths = [
      "/home"
      "/root"
      "/srv"
      "/var/lib/nixos"
      "/etc/group"
      "/etc/machine-id"
      "/etc/NetworkManager/system-connections"
      "/etc/passwd"
      "/etc/subgid"
    ];

    exclude = [
      ".cache"
      ".git"
    ];

    extraBackupArgs = [
      "--exclude-caches"
      "--skip-if-unchanged"
      "--verbose"
      "--no-scan"
    ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 3"
      "--keep-monthly 6"
      "--keep-yearly 3"
    ];

    timerConfig = {
      RandomizedDelaySec = "1hr";
      OnCalendar = "02:00";
    };

  };

  systemd.services.restic-backups-backblaze.onFailure = [ "notify-backup-failed.service" ];

  systemd.services."notify-backup-failed" = {
    enable = true;
    description = "Notify on failed backup";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/backblaze/sentinel.env";
    };

    script = ''
      ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="Backup failed" "$WEBHOOK_URL"
    '';
  };
}
