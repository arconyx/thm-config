{ ... }: {
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
          tls
        }
      }
    '';
  };

  system.stateVersion = "26.11";
}
