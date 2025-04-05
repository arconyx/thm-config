{ pkgs, ... }:

{
  services.matrix-conduit = {
    enable = true;
    package = pkgs.conduwuit;
    settings = {
      global = {
        server_name = "thehivemind.gay";
        address = [
          "100.109.89.107"
          "fd7a:115c:a1e0::de01:596c"
        ];
        port = "8008";
        database_backend = "rocksdb";
        database_backup_path = "/srv/conduwuit-db-backups";
        database_backups_to_keep = 3;
        new_user_display_suffix = "🐝";
        allow_registration = true;
        registration_token_file = "/etc/conduwuit/reg_token";
        allow_encryption = true;
        allow_federation = true;
        require_auth_for_profile_requests = true;
        allow_public_room_directory_without_auth = false;
        allow_device_name_federation = false;
        # Protect display names
        allow_inbound_profile_lookup_federation_requests = false;
        trusted_servers = [
          "matrix.org"
          "envs.net"
        ];
        # We don't trust our disk
        rocksdb_paranoid_file_checks = true;
      };
    };
  };

  # Additional backup paths
  services.restic.backups.backblaze.paths = [
    "/var/lib/matrix-conduit"
    "/etc/conduwunit"
  ];

  # TODO: Integrate with restic and automate online backups
  # systemd.services.restic-backups-backblaze = {
  #   conflicts = [ "conduit.service" ];
  #   postStop = [ "systemctl start conduit.service" ];
  # };

  # Conduwuit docs: Avoid using systemd-resolved as it does not perform very well under high load, and we have identified its DNS caching to not be very effective.
  services.resolved.enable = false;
}
