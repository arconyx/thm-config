{ config, lib, ... }:
{
  imports = [ ./local-backup.nix ];

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
    restic-backups-backblaze = lib.mkIf config.services.minecraft-servers.servers.magic.enable {
      conflicts = [ "minecraft-server-magic.service" ];
      after = [ "minecraft-server-magic.service" ];
      onSuccess = [ "minecraft-server-magic.service" ];
    };
  };
}
