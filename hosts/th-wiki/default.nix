{ ... }: {
  imports = [ ./../../tierhive ];

  services.restic.backups.backblaze.repository =
    "s3:https://s3.us-west-004.backblazeb2.com/thm-wiki-restic";

  system.stateVersion = "26.11";

}
