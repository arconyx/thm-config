{ ... }:
{
  imports = [
    ./../home
    ./../units
  ];

  arcworks.services.backups = {
    backup.backblaze = {
      repository = "s3:https://s3.us-west-004.backblazeb2.com/thm-restic-backup-bucket";
      environmentFile = "/etc/backblaze/backblaze.env";
      passwordFile = "/etc/backblaze/backblaze.passphrase";
      statusEnvFile = "/etc/backblaze/sentinel.env";
    };
  };
}
