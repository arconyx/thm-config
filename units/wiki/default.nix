{
  config,
  pkgs,
  lib,
  ...
}:
let
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

  # stuff added to path at runtime
  toolsPath = pkgs.symlinkJoin {
    name = "mediawiki-path";
    paths = [
      pkgs.diffutils
      pkgs.imagemagick
    ];
  };

  # we make a custom package by overwriting basePkgs
  basePkg = pkgs.mediawiki;
  # Attribute set of paths whose content is copied to the {file}`skins`
  # subdirectory of the MediaWiki installation in addition to the default skins.
  # types.attrsOf types.path
  skins = {
    MonoBook = "${basePkg}/share/mediawiki/skins/MonoBook";
    Timeless = "${basePkg}/share/mediawiki/skins/Timeless";
    Vector = "${basePkg}/share/mediawiki/skins/Vector";
  };
  # Attribute set of paths whose content is copied to the {file}`extensions`
  # subdirectory of the MediaWiki installation and enabled in configuration.
  # Use `null` instead of path to enable extensions that are part of MediaWiki.
  # types.attrsOf (types.nullOr types.path)
  extensions =
    let
      wsoAuth = php.buildComposerProject2 {
        pname = "WSOAuth";
        version = "9.0.1";

        src = pkgs.fetchFromGitHub {
          owner = "wikimedia";
          repo = "mediawiki-extensions-WSOAuth";
          rev = "0d02ee546dd3211a9899c4cd772f240fd3fc8277";
          hash = "sha256-mBDn4x72uz6sKXqdHjBWs2GSNIQcb0kTBwyOsElRn64=";
        };

        patches = [
          ./discord-auth.patch
        ];

        composerLock = ./wsoauth-composer.lock;
        # manually test validation with `composer validate`
        # it doesn't like the missing name and description fields
        composerStrictValidation = false;

        vendorHash = "sha256-VXUqCRjWNSzgLx/hTIiw0yeLcYaawsePRn/D05L+CQA=";
      };
    in
    {
      VisualEditor = null;
      # TODO: update extensions
      PluggableAuth = pkgs.fetchFromGitHub {
        owner = "wikimedia";
        repo = "mediawiki-extensions-PluggableAuth";
        rev = "85e96acd1ac0ebcdaa29c20eae721767a938f426";
        hash = "sha256-bMVhrg8FsfWhXF605Cj5TgI0A6Jy/MIQ5aaUcLQQ0Ss=";
      };
      UserMerge = pkgs.fetchFromGitHub {
        owner = "wikimedia";
        repo = "mediawiki-extensions-UserMerge";
        rev = "7c38852e2d2bbd92fe100bd3587768ae5f5115b6";
        hash = "sha256-LspMbtbDi2e3cS4er/wXuPu5O9MN0cxx0iKEZsPjV8U=";
      };
      # composer.lock added in patch
      # generated with `composer update --no-dev` using nixpkgs#php83Packages.composer
      WSOAuth = "${wsoAuth}/share/php/WSOAuth";
    };
  icon = ./bee.svg;
  pkg = pkgs.stdenv.mkDerivation rec {
    pname = "mediawiki-full";
    inherit (src) version;
    src = basePkg;

    installPhase = ''
      mkdir -p $out
      cp -r * $out/

      substituteInPlace $out/share/mediawiki/includes/config-schema.php \
        --replace-fail "/usr/bin/" "${toolsPath}/bin/" \
        --replace-fail "\$path/" "${toolsPath}/bin/"

      # add custom icon
      rm -rf $out/share/mediawiki/resources/assets/icon.svg
      ln -s ${icon} $out/share/mediawiki/resources/assets/icon.svg

      # try removing directories before symlinking to allow overwriting any builtin extension or skin
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: ''
          rm -rf $out/share/mediawiki/skins/${k}
          ln -s ${v} $out/share/mediawiki/skins/${k}
        '') skins
      )}

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: ''
          rm -rf $out/share/mediawiki/extensions/${k}
          ln -s ${
            if v != null then v else "$src/share/mediawiki/extensions/${k}"
          } $out/share/mediawiki/extensions/${k}
        '') extensions
      )}
    '';
  };

  # make mediawiki admin scripts available to user
  mediawikiScripts =
    pkgs.runCommand "mediawiki-scripts"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        preferLocalBuild = true;
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${php}/bin/php $out/bin/mediawiki-maintenance \
          --set MEDIAWIKI_CONFIG ${mediawikiConfig} \
          --add-flags ${pkg}/share/mediawiki/maintenance/run.php

        for i in changePassword createAndPromote deleteUserEmail renameUser resetUserEmail userOptions edit nukePage update importDump run; do
          script="$out/bin/mediawiki-$i"
        cat <<'EOF' >"$script"
        #!${pkgs.runtimeShell}
        become=(exec)
        if [[ "$(id -u)" != ${user} ]]; then
          become=(exec /run/wrappers/bin/sudo -u ${user} --)
        fi
        "${"$"}{become[@]}" ${placeholder "out"}/bin/mediawiki-maintenance \
        EOF
          if [[ "$i" != "run" ]]; then
            echo "  ${pkg}/share/mediawiki/maintenance/$i.php \"\$@\"" >>"$script"
          else
            echo "  ${pkg}/share/mediawiki/maintenance/\$1.php \"\''${@:2}\"" >>"$script"
          fi
          chmod +x "$script"
        done
      '';

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
        $wgArticlePath = "/wiki/$1";

        ## The protocol and server name to use in fully-qualified URLs
        $wgServer = "https://thehivemind.gay";

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
            'username'  => 'getenv('SMTP_USERNAME')',     // Username to use for SMTP authentication (if being used)
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
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "wfLoadSkin('${k}');") skins)}

        # Enabled extensions.
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "wfLoadExtension('${k}');") extensions)}

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

        # broken
        $wgDebugLogFile = "/proc/self/fd/1";
    '';
  };
in
{
  options.arc.services.wiki = {
    enable = lib.mkEnableOption "THM Wiki";
    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkg;
    };
  };

  config = lib.mkIf config.arc.services.wiki.enable {
    services.phpfpm.pools.mediawiki = {
      inherit user group;
      phpEnv.MEDIAWIKI_CONFIG = "${mediawikiConfig}";
      phpPackage = php;
      phpOptions = ''
        ; allow_url_fopen is slightly insecure (only if there are other vulns) but is needed for DiscordAuth (line 86 of DiscordAuth.php)
        allow_url_fopen = 1
        session.use_trans_sid = 0
        log_errors = 1
        error_log = "syslog"
      '';
      settings = {
        "listen.owner" = "caddy";
        "listen.group" = "caddy";

        # nixos mediawiki defaults
        # "pm" = "dynamic";
        # "pm.max_children" = 32;
        # "pm.start_servers" = 2;
        # "pm.min_spare_servers" = 2;
        # "pm.max_spare_servers" = 4;
        # "pm.max_requests" = 500;

        # tuned for pi
        "pm" = "ondemand";
        "pm.max_children" = 6;
        "pm.max_requests" = 500;

        "catch_workers_output" = "yes";
        "decorate_workers_output" = "no";
        "access.log" = "/proc/self/fd/1";
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

    environment.systemPackages = [ mediawikiScripts ];

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
      ];
    };
  };
}
