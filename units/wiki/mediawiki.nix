{
  stdenvNoCC,
  lib,
  # base package to modify
  mediawiki,

  # tools
  symlinkJoin,
  diffutils,
  imagemagick,

  # for extensions
  php,
  fetchFromGitHub,
}:
let
  # stuff added to path at runtime
  toolsPath = symlinkJoin {
    name = "mediawiki-path";
    paths = [
      diffutils
      imagemagick
    ];
  };

  # Attribute set of paths whose content is copied to the {file}`skins`
  # subdirectory of the MediaWiki installation in addition to the default skins.
  # types.attrsOf types.path
  skins = {
    MonoBook = "${mediawiki}/share/mediawiki/skins/MonoBook";
    Timeless = "${mediawiki}/share/mediawiki/skins/Timeless";
    Vector = "${mediawiki}/share/mediawiki/skins/Vector";
  };

  # Attribute set of paths whose content is copied to the {file}`extensions`
  # subdirectory of the MediaWiki installation and enabled in configuration.
  # Use `null` instead of path to enable extensions that are part of MediaWiki.
  extensions =
    let
      wsoAuth = php.buildComposerProject2 {
        pname = "WSOAuth";
        version = "9.0.1";

        src = fetchFromGitHub {
          owner = "wikimedia";
          repo = "mediawiki-extensions-WSOAuth";
          rev = "0fd5fc2300c877ca7ef8f1e3b811caec4acccbf1";
          hash = "sha256-04VCOKfrgrijrv9CdjXeaExmAsxIEWcWMz8W2KVutGI=";
        };

        patches = [
          ./wsoauth/discord-auth.patch
        ];

        # Generated with `composer update --no-install --no-dev`
        # in a local clone of the repo with the Discord patch applied
        composerLock = ./wsoauth/wsoauth-composer.lock;

        # manually test validation with `composer validate`
        # it doesn't like the missing name and description fields
        composerStrictValidation = false;

        vendorHash = "sha256-ewQeiUT4/0FnzCayjDXOKFfXPfFBFOxnzjcuN9kFSsU=";
      };
    in
    {
      VisualEditor = null;
      # TODO: Enable for template parameters
      # https://www.mediawiki.org/wiki/Extension:TemplateData
      TemplateData = null;
      # TODO: update extensions
      PluggableAuth = fetchFromGitHub {
        owner = "wikimedia";
        repo = "mediawiki-extensions-PluggableAuth";
        rev = "85e96acd1ac0ebcdaa29c20eae721767a938f426";
        hash = "sha256-bMVhrg8FsfWhXF605Cj5TgI0A6Jy/MIQ5aaUcLQQ0Ss=";
      };
      UserMerge = fetchFromGitHub {
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
in
stdenvNoCC.mkDerivation rec {
  pname = "mediawiki-full";
  inherit (src) version;

  src = mediawiki;

  __structuredAttrs = true;
  inherit skins extensions;

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
}
