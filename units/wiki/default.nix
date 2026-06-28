{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.thm.services.wiki;

  # php version
  # https://www.mediawiki.org/wiki/Compatibility#PHP
  php = pkgs.php83;

  # user for php and stuff
  user = "mediawiki";
  group = "mediawiki";

  # storage dirs
  cacheDir = "/var/cache/mediawiki";
  baseStateDir = "/var/lib/mediawiki";
  stateDir = "${baseStateDir}/state"; # TODO: Add to backups?
  dbDir = "${baseStateDir}/db";
  uploadsDir = "${baseStateDir}/uploads";

  pkg = pkgs.callPackage ./mediawiki.nix {
    inherit php;
  };

  mediawikiConfig = pkgs.writeTextFile {
    name = "LocalSettings.php";
    checkPhase = ''
      ${php}/bin/php --syntax-check "$target"
    '';
    text = ''
      <?php
        # Protect against web entry
        if ( !defined( 'MEDIAWIKI' ) ) {
          exit;
        }

        $wgSitename = "THM Wiki";
        $wgMetaNamespace = false;

        ## The URL base path to the directory containing the wiki;
        ## defaults for all runtime URL paths are based off of this.
        ## For more information on customizing the URLs
        ## (like /w/index.php/Page_title to /wiki/Page_title) please see:
        ## https://www.mediawiki.org/wiki/Manual:Short_URL
        $wgScriptPath = "/mediawiki";
        $wgArticlePath = "/${cfg.articlePath}/$1";

        ## The protocol and server name to use in fully-qualified URLs
        $wgServer = "https://${cfg.domain}";

        ## The URL path to static resources (images, scripts, etc.)
        $wgResourceBasePath = $wgScriptPath;

        ## The URL path to the logo.  Make sure you change this from the default,
        ## or else you'll overwrite your logo when you upgrade!
        # TODO: Rename files on wiki
        # TODO: Add icon to package
        $wgLogos = [
            '1x' => "$wgResourceBasePath/resources/assets/icon.svg",
            'icon' => "$wgResourceBasePath/resources/assets/icon.svg",
        ];

        ## UPO means: this is also a user preference option

        $wgEnableEmail = true;
        # user-to-user email, on only for easy debugging using Special:EmailUser
        $wgEnableUserEmail = false; # UPO
        $wgPasswordSender = "wiki@thehivemind.gay";
        $wgSMTP = [
            'host'      => getenv('SMTP_HOST'), // could also be an IP address. Where the SMTP server is located. If using SSL or TLS, add the prefix "ssl://" or "tls://".
            'IDHost'    => 'thehivemind.gay',      // Generally this will be the domain name of your website (aka mywiki.org)
            'localhost' => 'thehivemind.gay',      // Same as IDHost above; required by some mail servers
            'port'      => 443,                // Port to use when connecting to the SMTP server
            'auth'      => true,               // Should we use SMTP authentication (true or false)
            'username'  => getenv('SMTP_USERNAME'),     // Username to use for SMTP authentication (if being used)
            'password'  => getenv('SMTP_PASSWORD')       // Password to use for SMTP authentication (if being used)
        ];


        $wgPasswordSender = "";

        $wgEnotifUserTalk = false; # UPO
        $wgEnotifWatchlist = false; # UPO
        $wgEmailAuthentication = true;

        ## Database settings
        $wgDBtype = "sqlite";
        $wgDBserver = "";
        $wgDBport = "";
        $wgDBname = "thm_wiki";
        $wgDBuser = "";
        $wgDBpassword = "";

        # SQLite-specific settings
        $wgSQLiteDataDir = "${dbDir}";
        $wgObjectCaches[CACHE_DB] = [
            'class' => SqlBagOStuff::class,
            'loggroup' => 'SQLBagOStuff',
            'server' => [
                'type' => 'sqlite',
                'dbname' => 'wikicache',
                'tablePrefix' => "",
                'variables' => [ 'synchronous' => 'NORMAL' ],
                'dbDirectory' => $wgSQLiteDataDir,
                'trxMode' => 'IMMEDIATE',
                'flags' => 0
            ]
        ];
        $wgLocalisationCacheConf['storeServer'] = [
            'type' => 'sqlite',
            'dbname' => "{$wgDBname}_l10n_cache",
            'tablePrefix' => "",
            'variables' => [ 'synchronous' => 'NORMAL' ],
            'dbDirectory' => $wgSQLiteDataDir,
            'trxMode' => 'IMMEDIATE',
            'flags' => 0
        ];
        $wgJobTypeConf['default'] = [
            'class' => 'JobQueueDB',
            'claimTTL' => 3600,
            'server' => [
                'type' => 'sqlite',
                'dbname' => "{$wgDBname}_jobqueue",
                'tablePrefix' => "",
                'variables' => [ 'synchronous' => 'NORMAL' ],
                'dbDirectory' => $wgSQLiteDataDir,
                'trxMode' => 'IMMEDIATE',
                'flags' => 0
            ]
        ];
        $wgResourceLoaderUseObjectCacheForDeps = true;

        ## Shared memory settings
        $wgMainCacheType = CACHE_NONE;
        $wgMemCachedServers = [];

        $wgEnableUploads = true;
        $wgUploadDirectory = "${uploadsDir}";

        $wgUseImageMagick = true;

        # InstantCommons allows wiki to use images from https://commons.wikimedia.org
        $wgUseInstantCommons = false;

        # Periodically send a pingback to https://www.mediawiki.org/ with basic data
        # about this MediaWiki instance. The Wikimedia Foundation shares this data
        # with MediaWiki developers to help guide future development efforts.
        $wgPingback = true;

        ## If you use ImageMagick (or any other shell command) on a
        ## Linux server, this will need to be set to the name of an
        ## available UTF-8 locale
        $wgShellLocale = "C.UTF-8";

        ## Set $wgCacheDirectory to a writable directory on the web server
        ## to make your wiki go slightly faster. The directory should not
        ## be publicly accessible from the web.
        $wgCacheDirectory = "${cacheDir}";

        # Site language code, should be one of the list in ./languages/data/Names.php
        $wgLanguageCode = "en-gb";

        $wgSecretKey = file_get_contents("${stateDir}/secret.key");

        # Changing this will log out all existing sessions.
        # I suppose having this set is marginally better than it being empty
        $wgAuthenticationTokenVersion = "notanullstring";

        ## For attaching licensing metadata to pages, and displaying an
        ## appropriate copyright notice / icon. GNU Free Documentation
        ## License and Creative Commons licenses are supported so far.
        $wgRightsPage = ""; # Set to the title of a wiki page that describes your license/copyright
        $wgRightsUrl = "";
        $wgRightsText = "";
        $wgRightsIcon = "";

        # Enabled skins.
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "wfLoadSkin('${k}');") pkg.skins)}

        # Enabled extensions.
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (k: v: "wfLoadExtension('${k}');") pkg.extensions
        )}

        # End of automatically generated settings.
        # Add more configuration options below.

        $wgDefaultSkin = 'timeless';

        $wgGroupPermissions['*']['createaccount'] = false;
        $wgGroupPermissions['*']['edit'] = false;
        $wgGroupPermissions['*']['read'] = false;

        $wgPluggableAuth_EnableLocalLogin = true;
        $wgGroupPermissions['*']['autocreateaccount'] = true;
        $wgPluggableAuth_EnableLocalProperties = true;

        $wgOAuthCustomAuthProviders = [
            'discord' => \WSOAuth\AuthenticationProvider\DiscordAuth::class
        ];
        $wgPluggableAuth_Config['discord'] = [
            'plugin' => 'WSOAuth',
            'data' => [
                'type' => 'discord',
                'clientId' => getenv('DISCORD_CLIENT_ID'),
                'clientSecret' => getenv('DISCORD_CLIENT_SECRET'),
                'redirectUri' => 'https://thehivemind.gay/mediawiki/index.php?title=Special:PluggableAuthLogin',
                'extensionData' => [
                    'botToken' => getenv('DISCORD_BOT_TOKEN'),
                    'guildId' => getenv('DISCORD_GUILD_ID')
                ]
            ],
            'buttonLabelMessage' => 'wsoauth-login-with-discord'
        ];

        $wgGroupPermissions['bureaucrat']['usermerge'] = true;
        $wgGroupPermissions['sysop']['usermerge'] = true;
    '';
  };
in
{
  options.thm.services.wiki = {
    enable = lib.mkEnableOption "THM Wiki";
    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkg;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      example = "example.thehivemind.gay";
      description = ''
        The public host for the wiki.

        This expects to be the only service on the (sub)domain and will configure
        the reverse proxy as such.
      '';
    };
    articlePath = lib.mkOption {
      type = lib.types.str;
      example = "wiki";
      description = ''
        The article path for the wiki, relative to the host root.
        e.g. 'wiki' in https://example.thehivemind.gay/wiki/Main_Page'';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.caddy.serviceConfig.SupplementaryGroups = [ "mediawiki" ];
    services.caddy = {
      enable = true;
      virtualHosts = {
        # we expect to behind a cloudflare tunnel that will handle tls termination
        "${cfg.domain}:80" = {
          extraConfig = ''
            # rewrite domain root to main page
            rewrite / /mediawiki/index.php

            # allow accessing pages at example.com/w/Article_Title
            redir /${cfg.articlePath} /${cfg.articlePath}/
            rewrite /${cfg.articlePath}/* /mediawiki/index.php?title={path}
            rewrite /${cfg.articlePath}/rest.php/* /mediawiki/rest.php?{query}

            handle /mediawiki/* {
              # don't use php for images subfolder
              @wiki_noimages {
                path /mediawiki/*
                not path /mediawiki/images*

                # since we block access here we also need to hide
                # it from the file server
                not path /mediawiki/LocalSettings.php
              }

              php_fastcgi @wiki_noimages unix/${config.services.phpfpm.pools.mediawiki.socket}

              handle_path /mediawiki/images/* {
                root /var/lib/mediawiki/uploads
                # this is recommended by mediawiki
                header /mediawiki/images X-Content-Type-Options nosniff
                encode zstd gzip
                file_server
              }

              # Enable the static file server.
              file_server @wiki_noimages {
                root ${cfg.finalPackage}/share
                hide LocalSettings.php *.php
              }
            }

            encode zstd gzip

            handle_errors {
              respond "{err.status_code} {err.status_text}"
            }
          '';
        };
      };
    };

    # eww, phpfpm is run as root and only changes owner of child processes
    # TODO: See about reimplementing phpfpm services more locked down
    # This would also allow using StateDirectory instead of systemd-tmpfiles
    services.phpfpm.pools.mediawiki = {
      inherit user group;
      phpEnv.MEDIAWIKI_CONFIG = "${mediawikiConfig}";
      phpPackage = php;
      phpOptions = ''
        ; allow_url_fopen is slightly insecure (only if there are other vulns) but is needed for DiscordAuth (line 86 of DiscordAuth.php)
        allow_url_fopen = 1
        session.use_trans_sid = 0
        log_errors = 1
      '';
      settings = {
        "listen.owner" = "caddy";
        "listen.group" = "caddy";

        "catch_workers_output" = true;
        "decorate_workers_output" = false;

        # this is the nixos mediawiki defaults
        # pm is mandatory
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
      };
      phpEnv = {
        DISCORD_CLIENT_ID = "$DISCORD_CLIENT_ID";
        DISCORD_CLIENT_SECRET = "$DISCORD_CLIENT_SECRET";
        DISCORD_BOT_TOKEN = "$DISCORD_BOT_TOKEN";
        DISCORD_GUILD_ID = "$DISCORD_GUILD_ID";
        SMTP_HOST = "$SMTP_HOST";
        SMTP_USERNAME = "$SMTP_USERNAME";
        SMTP_PASSWORD = "$SMTP_PASSWORD";
      };
    };

    users.users.mediawiki = {
      group = "mediawiki";
      isSystemUser = true;
    };
    users.groups.mediawiki = { };

    # Make mediawiki admin scripts avaiable to the user
    environment.systemPackages = [
      (pkgs.callPackage ./scripts.nix {
        wikiPhp = php;
        wikiPkg = pkg;
        wikiUser = user;
        wikiConfig = mediawikiConfig;
      })
    ];

    systemd.tmpfiles.rules = [
      "d '${baseStateDir}' 0750 ${user} ${group} - -"
      "d '${stateDir}' 0750 ${user} ${group} - -"
      "d '${dbDir}' 0700 ${user} ${group} - -"
      "d '${cacheDir}' 0750 ${user} ${group} - -"
      "d '${uploadsDir}' 0750 ${user} ${group} - -"
      "Z '${uploadsDir}' 0750 ${user} ${group} - -"
    ];

    systemd.services.mediawiki-init = {
      wantedBy = [ "multi-user.target" ];
      before = [ "phpfpm-mediawiki.service" ];
      # We rip out the fancy db init and replace it with an expectation that the db exists
      script = ''
        if ! test -e "${stateDir}/secret.key"; then
          tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c 64 > ${stateDir}/secret.key
        fi

        ${php}/bin/php ${pkg}/share/mediawiki/maintenance/run.php eval --conf ${mediawikiConfig}
        ${php}/bin/php ${pkg}/share/mediawiki/maintenance/update.php --conf ${mediawikiConfig} --quick --skip-external-dependencies
      '';

      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = group;
        PrivateTmp = true;
      };
    };

    systemd.services.phpfpm-mediawiki.serviceConfig.EnvironmentFile = "/etc/mediawiki/secrets.env";

    services.restic.backups.backblaze = {
      backupPrepareCommand = "${php}/bin/php ${pkg}/share/mediawiki/maintenance/run.php SqliteMaintenance --backup-to /tmp/wiki.backup --conf ${mediawikiConfig}";
      backupCleanupCommand = "rm /tmp/wiki.backup";
      paths = [
        "/tmp/wiki.backup"
        uploadsDir
        stateDir
      ];
    };
  };
}
