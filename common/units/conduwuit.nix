{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:

let
  ooye = inputs.ooye.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (
    finalAttrs: prevAttrs: {
      version = "3";

      src = prevAttrs.src.override {
        rev = "f7ba176a7e37e13950490422def3e5386ed3dd40";
        sha256 = "fPAJuWVclFMslc0SaaCwcQTuD1oJE+AbPU9FDmUtuns=";
      };

      npmDepsHash = "sha256-pSyEhTnBY++FETfrkAy7wXqu36u8nD6pUMuOfl2dII4=";

      npmDeps = pkgs.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };
    }
  );
in
{
  imports = [ ./caddy.nix ];

  # binary cache for conduwuit
  nix.settings.substituters = lib.mkAfter [ "https://attic.kennel.juneis.dog/conduwuit" ];
  nix.settings.trusted-public-keys = lib.mkAfter [
    "conduwuit:BbycGUgTISsltcmH0qNjFR9dbrQNYgdIAcmViSGoVTE="
  ];

  # Matrix homeserver
  services.matrix-conduit = {
    enable = true;
    package = inputs.conduwuit.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings = {
      global = {
        server_name = "thehivemind.gay";
        address = "::1";
        port = 8008;
        database_backend = "rocksdb";
        database_backup_path = "/srv/conduwuit-db-backups"; # TODO: Test permissions
        database_backups_to_keep = 3;
        new_user_displayname_suffix = "🐝";
        allow_registration = true;
        registration_token_file = "/run/credentials/conduit.service/reg_token";
        allow_encryption = true;
        # We can't enable federation because we don't have e2e in the group
        # and leaking information to third party homeservers is icky.
        allow_federation = false;
        require_auth_for_profile_requests = true;
        allow_public_room_directory_without_auth = false;
        allow_device_name_federation = false;
        # Protect display names
        allow_inbound_profile_lookup_federation_requests = false;
        # We don't trust our disk
        rocksdb_paranoid_file_checks = true;
      };
    };
  };

  # Additional backup paths
  services.restic.backups.backblaze.paths = [
    "/var/lib/matrix-conduit"
    "/etc/conduwuit"
    "/etc/ooye"
  ];

  # TODO: Integrate with restic and automate online backups
  # systemd.services.restic-backups-backblaze = {
  #   conflicts = [ "conduit.service" ];
  #   postStop = [ "systemctl start conduit.service" ];
  # };

  # Conduwuit docs: Avoid using systemd-resolved as it does not perform very well under high load, and we have identified its DNS caching to not be very effective.
  services.resolved.enable = false;

  # Discord bridging with out of your element
  # This doesn't support end to bridge encryption so our rooms
  # will have to be unencrypted and unfederated :(
  services.matrix-ooye = {
    enable = true;
    appserviceId = "ooye";
    homeserver = "http://localhost:${builtins.toString config.services.matrix-conduit.settings.global.port}";
    homeserverName = "thehivemind.gay";
    discordTokenPath = "/etc/ooye/discord-token";
    discordClientSecretPath = "/etc/ooye/discord-client-secret";
    enableSynapseIntegration = false;
    socket = "6693";
    bridgeOrigin = "https://hive.tail564508.ts.net/ooye";
    package = ooye;
  };

  # Add ooye integration and access to config
  systemd.services.conduit = {
    after = [
      "matrix-ooye-pre-start.service"
      "network-online.target"
    ];
    requires = [
      "matrix-ooye-pre-start.service"
      "network-online.target"
    ];
    serviceConfig = {
      LoadCredential = [
        # "matrix-ooye-registration:/var/lib/matrix-ooye/registration.yaml"
        "reg_token:/etc/conduwuit/reg_token"
      ];
      # ExecStartPre = [
      #   "+${pkgs.coreutils}/bin/cp /run/credentials/conduit.service/matrix-ooye-registration ${config.services.matrix-conduit.settings.global.database_path}ooye-registration.yaml"
      #   "+${pkgs.coreutils}/bin/chown conduit:conduit ${config.services.matrix-conduit.settings.global.database_path}ooye-registration.yaml"
      # ];
      ExecStart = lib.mkForce "${config.services.matrix-conduit.package}/bin/conduwuit";
    };
  };

  # Proxy everything
  services.caddy.virtualHosts."hive.tail564508.ts.net".extraConfig = ''
        # ooye media server
        encode gzip
    	  handle_path /ooye/* {
          reverse_proxy :${config.services.matrix-ooye.socket} 
        }

        # conduwuit
        reverse_proxy [::1]:${builtins.toString config.services.matrix-conduit.settings.global.port}
  '';

}
