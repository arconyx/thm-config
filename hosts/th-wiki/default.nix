{ lib, ... }: {
  imports = [
    ./../../tierhive
    ./wiki
  ];

  thm.services.wiki = {
    enable = true;
    domain = "test.wiki.thehivemind.gay";
    articlePath = "w";
  };

  services.restic.backups.backblaze.repository =
    "s3:https://s3.us-west-004.backblazeb2.com/thm-wiki-restic";

  services.caddy = {
    openFirewall = true;
    globalConfig = ''
      servers {
        listener_wrappers {
          proxy_protocol {
            allow 10.0.0.0/24
            fallback_policy ignore
          }
        }
      }
    '';
  };

  nixpkgs.overlays = [
    (self: super: {
      php83 =
        let
          php = super.php83;
          version = "8.3.37";
        in
        if (lib.versionOlder php.version version) then
          builtins.trace "Using php ${version} override" php.override {
            inherit version;
            hash = "sha256-eDe0PNThjbXerCHubwCGbkd5pwXy5U+uqDyKbPVv0dg=";
          }
        else
          builtins.warn "Outdated php ${version} override ignored in favour of ${php.version}" php;
    })
  ];

  system.stateVersion = "26.11";
}
