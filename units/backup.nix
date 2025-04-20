{ ... }:

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
      "/var/backup"
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

  };

  systemd.timers.restic-backups-backblaze.timerConfig.RandomizedDelaySec = "1hr";

  # TODO: Notify on failure
}
