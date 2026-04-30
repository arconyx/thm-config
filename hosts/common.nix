{ pkgs, ... }:
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

  # Mitigate CVE-2026-31431
  # See affected version here: https://www.cve.org/CVERecord/?id=CVE-2026-31431
  # TODO: Remove once patch has made it into used kernel versions
  # Blacklisting disables automatic loading
  boot.blacklistedKernelModules = [ "algif_aead" ];
  # When manually loading run a dummy program instead
  boot.extraModprobeConfig = "install algif_aead ${pkgs.coreutils}/bin/false\n";
}
