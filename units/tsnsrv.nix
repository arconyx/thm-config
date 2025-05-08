{ ... }:
{
  services.tsnsrv = {
    enable = true;
    defaults = {
      authKeyPath = "/etc/tsnsrv/client.secret";
      ephemeral = true;
      tsnetVerbose = true;
      tags = [ "tag:tsnsrv" ];
    };
  };

  services.restic.backups.backblaze.paths = [ "/etc/tsnsrv" ];
}
