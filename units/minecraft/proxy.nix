{
  pkgs,
  lib,
  config,
  ...
}:
let
  settingsFormat = pkgs.formats.yaml { };
in
{
  options.thm.services.minecraft.proxy = {
    enable = lib.mkEnableOption "proxying of Minecraft servers";

    package = lib.mkPackageOption pkgs "gate" { };

    publicPort = lib.mkOption {
      type = lib.types.port;
      example = 12345;
      default = 25565;
      description = "External port exposed by Gate";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      example = "192.168.1.32";
      default = "0.0.0.0";
      description = "Address on which Gate listens";
    };

    openFirewall = lib.mkEnableOption "opening firewall for `publicPort`";

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
      };
      example = {
        connectionTimeout = "5s";
      };
      default = { };
      description = ''
        Additional settings merged into config.yml.

        Takes priority over settings declared in module config.
        Configuration reference: https://gate.minekube.com/guide/config/
      '';
    };

    routes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          { ... }:
          {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                example = false;
                default = true;
                description = "Defaults on but can be set to disable a particular route.";
              };

              host = lib.mkOption {
                type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
                example = "mc.example.com";
                description = ''
                  Match the virtual host address from the incoming connection

                  Wildcard matches ('*.example.com') are supported. Multiple hosts
                  can be supplied as a list.
                '';
              };

              backend = lib.mkOption {
                type = lib.types.str;
                example = "backend.example.com:25565";
                description = "The backend to connect to if matched";
              };

              fallback = {
                motd = lib.mkOption {
                  type = lib.types.str;
                  example = ''
                    §cServer is offline.
                    §eCheck back later!
                  '';
                  default = ''
                    §cServer is offline.
                    §eTry necromancy!
                  '';
                  description = "Message of the day";
                };
                version = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    example = "§cTry again later!";
                    default = "§cTry again later!";
                    description = "String, displayed as server version";
                  };
                  protocol = lib.mkOption {
                    type = lib.types.int;
                    example = 1;
                    default = -1;
                    description = "Server protocol version. Usually -1 for the fallback.";
                  };
                  favicon = lib.mkOption {
                    type = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);
                    description = "Path to an image file or base64 data uri (64x64 optimal)";
                    default = null;
                  };
                };
              };

              settings = lib.mkOption {
                type = lib.types.submodule {
                  freeformType = settingsFormat.type;
                };
                example = {
                  proxyProtocol = true;
                };
                default = { };
                description = ''
                  Additional settings merged into route options.

                  Takes priority over settings declared in module config.
                  Configuration reference: https://gate.minekube.com/guide/config/
                '';
              };
            };
          }
        )
      );
    };
  };

  config =
    let
      cfg = config.thm.services.minecraft.proxy;

      routeCfg =
        route:
        lib.recursiveUpdate {
          host = route.host;
          backend = route.backend;
          fallback = route.fallback;
        } route.settings;

      liveRoutes = builtins.filter (cfg: cfg.enable) cfg.routes;

      baseCfg = {
        config = {
          bind = "${cfg.bindAddress}:${toString cfg.publicPort}";
          lite = {
            enabled = true;
            routes = map routeCfg liveRoutes;
          };
        };
      };

      cfgFile = settingsFormat.generate "gate-config" (lib.recursiveUpdate baseCfg cfg.settings);
    in
    lib.mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.publicPort ];

      systemd.services.gate = {
        description = "A proxy for Minecraft servers powered by Gate";
        confinement = {
          enable = true;
          packages = [ cfgFile ];
        };

        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        startLimitBurst = 5;
        startLimitIntervalSec = 120;

        environment = {
          GATE_CONFIG = cfgFile;
        };

        serviceConfig = {
          DynamicUser = true;

          Type = "exec";
          ExecStart = "${lib.getExe cfg.package}";
          Restart = "always";

          # Hardening, sections named after man page sections in systemd.exec
          # Capabilities
          CapabilitiesBoundingSet = "";
          # Security
          NoNewPrivileges = true;
          # Sandboxing
          # ProtectSystem is not used because RootDirectory from nixos
          # confinement prevents access to the fs anyway
          # Same for the other fs options
          # Confinement also sets some other Private and Protect options
          # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/security/systemd-confinement.nix
          ProtectHostname = true;
          ProtectClock = true;
        };

      };
    };
}
