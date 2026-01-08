{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ./ephemeral.nix
    ./proxy.nix
  ];

  options.thm.services.minecraft = {
    enable = lib.mkEnableOption "Minecraft server hosting";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "etc/minecraft/server.env";
      description = "
      Path to environment file for servers.
      
      We expect this to include a value for `DISCORD_WEBHOOK_URL`.
      ";
    };

    rcon-password = lib.mkOption {
      type = lib.types.singleLineStr;
      example = "239rjwfraw354i9aw3r";
      description = ''
        Password used to connect to remote command port
              
        This is plaintext in the store and worse, on github. This is acceptable
        because we keep the rcon port closed so it can only be accessed locally.
      '';
    };

    jvmOpts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [
        "-Xms8G"
        "-Xmx8G "
      ];
      description = "Default options passed to Java VM for all servers";
    };

    servers = lib.mkOption {
      default = { };
      description = ''Servers managed with this module'';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              enable = lib.mkEnableOption "Enable this minecraft server";

              package = lib.mkPackageOption pkgs.quiltServers "quilt" {
                default = null;
                pkgsText = "pkgs.quiltServers";
                extraDescription = ''
                  Minecraft server package from https://github.com/Infinidoge/nix-minecraft/.
                '';
              };

              alwaysOn = lib.mkEnableOption "the server starts automatically and doesn't idle timeout";

              operators = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      uuid = lib.mkOption {
                        type = lib.types.str;
                        description = "The operator's UUID";
                        example = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
                      };
                      level = lib.mkOption {
                        type = lib.types.ints.between 0 4;
                        description = "The operator's permission level";
                        default = 4;
                      };
                      bypassesPlayerLimit = lib.mkOption {
                        type = lib.types.bool;
                        description = "If true, the operator can join the server even if the player limit has been reached";
                        default = false;
                      };
                    };
                  }
                );
                example = {
                  ArcOnyx = {
                    uuid = "36322fea-3925-4ee1-a160-1f068e7cef44";
                    level = 4;
                    bypassesPlayerLimit = true;
                  };
                };
                default = { };
                description = ''
                  Server operators. To use imperative configuration leave empty.
                '';
              };

              port = lib.mkOption {
                type = lib.types.port;
                example = 1234;
                default = 25565;
                description = "Port the server listens on";
              };

              rcon-port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                example = 1244;
                default = config.thm.services.minecraft.servers.${name}.port + 10;
                description = ''
                  Port the rcon management server listens on.

                  If null we default to the game port + 10.'';
              };

              jvmOpts = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                example = [
                  "-Xms8G"
                  "-Xmx8G "
                ];
                # TODO: Will this merge or overwrite?
                # Merge I suspect, which could prove a problem.
                default = config.thm.services.minecraft.jvmOpts;
                description = "Options passed to Java VM. Defaults to global value.";
              };

              rcon-password = lib.mkOption {
                type = lib.types.singleLineStr;
                example = "239rjwfraw354i9aw3r";
                default = config.thm.services.minecraft.rcon-password;
                description = ''
                  Password used to connect to remote command port
                        
                  This is plaintext in the store and worse, on github. This is acceptable
                  because we keep the rcon port closed so it can only be accessed locally.

                  Defaults to the global value
                '';
              };

              settings = {

                gamemode = lib.mkOption {
                  type = lib.types.enum [
                    "survival"
                    "creative"
                    "spectator"
                    "adventure"
                  ];
                  example = "survival";
                  description = "Default player gamemode";
                };

                difficulty = lib.mkOption {
                  type = lib.types.enum [
                    "peaceful"
                    "easy"
                    "normal"
                    "hard"
                  ];
                  example = "normal";
                  default = "hard";
                  description = "Game difficulty";
                };

                motd = lib.mkOption {
                  type = lib.types.str;
                  example = "Server opening today";
                  default = "We are the Hive Mive";
                  description = "Message of the day, displayed in the server list";
                };

                distance = {
                  view = lib.mkOption {
                    type = lib.types.ints.between 3 32;
                    example = 16;
                    default = 12;
                    description = "Server render distance";
                  };
                  simulation = lib.mkOption {
                    type = lib.types.ints.between 3 32;
                    example = 16;
                    default = 8;
                    description = "Distance in which entities are ticked. Should be <= render distance.";
                  };
                };

                extraConfig = lib.mkOption {
                  type = lib.types.attrsOf (
                    lib.types.oneOf (
                      with lib.types;
                      [
                        bool
                        int
                        str
                      ]
                    )
                  );
                  default = { };
                  example = {
                    region-file-compression = "lz4";
                  };
                  description = ''Additional values added to server.properties'';
                };

              };

              symlinks = lib.mkOption {
                type = lib.types.attrsOf lib.types.pathInStore;
                example = {
                  mods = "\${modpack}/mods";
                };
                default = { };
                description = "Paths symlinked into the game directory";
              };

              files = lib.mkOption {
                type = lib.types.attrsOf lib.types.pathInStore;
                example = {
                  config = "\${modpack}/config";
                };
                default = { };
                description = ''
                  Paths copied into the game directory.

                  These are writeable, which is good when a mod doesn't like having
                  its config readonly. Changes to files will be lost when the server stops. 
                '';
              };

              backup = lib.mkOption {
                type = lib.types.bool;
                default = true;
                example = false;
                description = ''
                  Whether to backup this server.

                  Test servers may wish to disable this to save backup space.
                '';
              };

              serviceName = lib.mkOption {
                type = lib.types.str;
                default = "minecraft-server-${name}.service";
                readOnly = true;
                visible = false;
              };
            };
          }
        )
      );
    };
  };

  config =
    let
      globalCfg = config.thm.services.minecraft;
    in
    lib.mkIf globalCfg.enable (
      let
        servers = lib.filterAttrs (_: cfg: cfg.enable) globalCfg.servers;

        # this is a function from server name to path
        # string -> spath
        socket = config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path;

        # similar functions
        data_dir = name: config.systemd.services."minecraft-server-${name}".serviceConfig.WorkingDirectory;
      in
      {
        assertions =
          let
            ports = lib.mapAttrsToList (_: cfg: cfg.port) servers;
            rcon = lib.mapAttrsToList (_: cfg: cfg.rcon-port) servers;
          in
          [
            {
              assertion = lib.lists.allUnique ports;
              message = "Game ports must be unique across enabled servers";
            }
            {
              assertion = lib.lists.allUnique rcon;
              message = "rcon ports must be unique across enabled servers";
            }
            {
              assertion = lib.lists.mutuallyExclusive ports rcon;
              message = "Game and rcon ports cannot overlap";
            }
            {
              assertion = lib.lists.all (cfg: cfg.settings.distance.simulation <= cfg.settings.distance.view) (
                builtins.attrValues servers
              );
              message = "Simulation distance should be no more than the render distance";
            }
          ];

        # Shared server config
        services.minecraft-servers = {
          enable = true;
          eula = true;
          openFirewall = false;
          dataDir = "/srv/minecraft";
          environmentFile = globalCfg.environmentFile;
          managementSystem = {
            tmux.enable = false;
            systemd-socket.enable = true;
          };
        };

        # Server module from https://github.com/Infinidoge/nix-minecraft
        services.minecraft-servers.servers = lib.concatMapAttrs (
          name: cfg:
          let
            # This can't have trailing whitespace because it breaks `${msg-discord "whatever"} || echo "err msg"`
            msg-discord =
              msg:
              lib.strings.trim ''${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="[${name}] ${msg}" "$DISCORD_WEBHOOK_URL"'';
          in
          {
            ${name} = {
              enable = true;
              package = cfg.package;

              autoStart = cfg.alwaysOn;
              jvmOpts = cfg.jvmOpts;
              operators = cfg.operators;
              openFirewall = false;
              restart = if cfg.alwaysOn then "always" else "on-failure";

              serverProperties =
                let
                  sc = cfg.settings;
                in
                lib.mkMerge [
                  {
                    enable-command-block = true;
                    allow-flight = true;
                    white-list = true;
                    enforce-whitelist = true;
                    spawn-protection = 0;
                    initial-disabled-packs = "";

                    enable-rcon = true;
                    "rcon.password" = globalCfg.rcon-password;
                    "rcon.port" = cfg.rcon-port;

                    server-port = cfg.port;

                    gamemode = sc.gamemode;
                    difficulty = sc.difficulty;
                    motd = sc.motd;
                    view-distance = sc.distance.view;
                    simulation-distance = sc.distance.simulation;
                  }
                  sc.extraConfig
                ];

              symlinks = cfg.symlinks;
              files = cfg.files;

              # Notify Discord on start
              extraStartPre = ''
                ${msg-discord "Raising the server from the dead"} || echo "Unable to notify Discord of start"
              '';

              # Provide a 60 second warning before shutdown
              extraStopPre = ''
                echo "say Server shutdown in 60 seconds" > "${socket name}" && sleep 60 || echo "Unable to send shutdown warning"
              '';

              extraStopPost = ''
                if [ "$SERVICE_RESULT" != "success" ]; then
                  ${msg-discord "Server crash detected.\nIf it does not restart automatically within 10 minutes ping ArcOnyx.\nCrash type: $SERVICE_RESULT"}
                fi
              '';
            };
          }
        ) servers;

        systemd.services = lib.mkMerge [
          {
            # this runs even if backups are disabled for the server
            # since we want the server offline to speedup backups
            minecraft-post-remote-backup =
              let
                persistentServers = lib.mapAttrsToList (name: cfg: cfg.serviceName) (
                  lib.filterAttrs (_: cfg: cfg.alwaysOn) servers
                );
              in
              {
                enable = true;
                description = "Notify Discord about finished backup and restart servers'";
                script = ''
                  ${pkgs.curl}/bin/curl --silent -F username=${config.networking.hostName} -F content="Backup done." "$DISCORD_WEBHOOK_URL"
                '';
                serviceConfig = {
                  DynamicUser = true;
                  Type = "oneshot";
                  EnvironmentFile = globalCfg.environmentFile;
                };
                wantedBy = [ "restic-backups-backblaze.service" ];
                after = [ "restic-backups-backblaze.service" ];
                # Tried to use `wants+before` here but it silently failed to trigger server launch
                onSuccess = persistentServers;
                onFailure = persistentServers;
              };
          }
          (lib.concatMapAttrs (name: cfg: {
            "minecraft-server-${name}" = {
              # increased to "2min 15s" account for shutdown warning
              # increased futher to "5min" because the forever server keeps
              # being incredibly slow
              serviceConfig.TimeoutStopSec = lib.mkForce "5min";
              wants = [ "minecraft-servers.target" ];
              after = [ "restic-backups-backblaze.service" ];
              conflicts = [ "restic-backups-backblaze.service" ];
            };

            "minecraft-local-backup-${name}" = lib.mkIf cfg.backup {
              enable = true;
              description = "Backup Minecraft server to a local folder";
              conflicts = [ "restic-backups-backblaze.service" ];
              before = [ cfg.serviceName ];
              onFailure = [ "notify-minecraft-backup-failed-${name}.service" ];
              serviceConfig = {
                User = config.services.minecraft-servers.user;
                Group = config.services.minecraft-servers.group;
                Type = "oneshot";
              };
              script = builtins.readFile ./backup.sh;
              path = [
                pkgs.sqlite
                pkgs.fd
              ];
              environment = {
                SAVE_WAIT_TIME = "60";
                DATA_DIR = data_dir name;
                BACKUP_ROOT = "${config.services.minecraft-servers.dataDir}/backup/${name}";
                SOCKET = socket name;
              };
            };

            # calls webhook to report failure
            "notify-minecraft-backup-failed-${name}" = lib.mkIf cfg.backup {
              enable = true;
              description = "Notify on failed local Minecraft backup";
              serviceConfig = {
                Type = "oneshot";
                EnvironmentFile = "/etc/backblaze/sentinel.env";
              };
              script = ''
                ${pkgs.curl}/bin/curl -F username=${config.networking.hostName} -F content="[${name}] Local Minecraft backup failed" "$WEBHOOK_URL"
              '';
            };
          }) servers)
        ];

        systemd.timers = lib.concatMapAttrs (name: cfg: {
          "minecraft-local-backup-${name}" = lib.mkIf cfg.backup {
            enable = true;
            description = "Run local backup of Minecraft server regularly";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "00/4:00";
              RandomizedDelaySec = "30min";
              Unit = "minecraft-local-backup-${name}.service";
            };
          };
        }) servers;

        systemd.targets.minecraft-servers = {
          enable = true;
          description = "Helper target for all minecraft servers";
        };

        environment.systemPackages = [ (pkgs.callPackage ./nbted.nix { }) ];

        arcworks.services.backups.global.exclude = # Distant horizons files can be regenerated
        [
          "DistantHorizons.sqlite"
          "DistantHorizons.sqlite-shm"
          "DistantHorizons.sqlite-wal"
          "${config.services.minecraft-servers.dataDir}/backup"
        ]
        ++
          # if backup is diabled for a server exclude it from the backup paths
          (lib.mapAttrsToList (name: cfg: data_dir name) (lib.filterAttrs (_: cfg: !cfg.backup) servers));
      }
    );
}
