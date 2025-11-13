{ pkgs, lib, ... }:

let
  default_world = ./inital_state;
  home = "/var/lib/space-engineers";

  data_dir = "${home}/se_instances";
  instance_name = "november2025";
  instance_dir = "${data_dir}/${instance_name}";
  init-world = pkgs.writeShellScript "init-world" ''
    set -eo pipefail
    if [ ! -d "${instance_dir}" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "${instance_dir}/Saves"
      ${pkgs.coreutils}/bin/cp -r --update=none "${default_world}/World" "${instance_dir}/Saves/StarSystem"
      ${pkgs.coreutils}/bin/cp --update=all "${default_world}/SpaceEngineers-Dedicated.cfg" "${instance_dir}"
      ${pkgs.coreutils}/bin/chmod -R a=rX,u+w "${data_dir}"
    fi
  '';

  backupRoot = "${home}/se-backup";
  container-name = "se-devidian";
in
{
  users.users.engineer = {
    # podman requires an assigned range
    autoSubUidGidRange = true;
    isSystemUser = true;
    group = "engineer";
    createHome = true;
    # podman stores config + volumes under home dir
    home = home;
    linger = true;
    useDefaultShell = true;
  };
  users.groups.engineer = { };
  nix.settings.allowed-users = [ "engineer" ];

  systemd.enableStrictShellChecks = lib.mkForce false;

  home-manager.users.engineer = {
    home.stateVersion = "25.05";
    home.homeDirectory = home;

    services.podman = {
      enable = true;
      volumes = {
        se_plugins = {
          description = "Plugins for Space Engineers";
          driver = "local";
          preserve = false;
        };
        se_server = {
          description = "Binaries for Space Engineers";
          driver = "local";
          preserve = false;
        };
        se_steamcmd = {
          description = "Steam CLI for Space Engineers";
          driver = "local";
          preserve = false;
        };
      };

      containers."${container-name}" = {
        autoStart = true;
        description = "Space Engineers server";
        image = "docker.io/devidian/spaceengineers:winestaging";
        network = "bridge";
        networkAlias = [ "se-server" ];
        ports = [
          "25565:25565/udp"
          "8080:8080"
        ];
        volumes = [
          "se_plugins:/appdata/space-engineers/plugins:rw"
          "${data_dir}:/appdata/space-engineers/instances:rw"
          "se_server:/appdata/space-engineers/SpaceEngineersDedicated:rw"
          "se_steamcmd:/root/.steam:rw"
        ];
        environment = {
          WINEDEBUG = "-all";
          INSTANCE_NAME = instance_name;
          PUBLIC_IP = "se.thehivemind.gay";
        };
        extraPodmanArgs = [ "--memory=8G" ];
      };
    };

    systemd.user.services.init-se-world = {
      Unit = {
        Description = "Initialise Space Engineers world";
        Before = [ "podman-${container-name}.service" ];
      };
      Install.RequiredBy = [ "podman-${container-name}.service" ];
      Service = {
        Type = "exec";
        ExecStart = init-world;
      };
    };

  };

  networking.firewall.allowedUDPPorts = [ 25565 ];

  arcworks.services.backups.backup.backblaze.paths = [ instance_dir ];

  systemd.services."se-local-backup" = {
    enable = true;
    description = "Backup Space Engineers server to a local folder";
    # don't run while other backups are running
    conflicts = [ "restic-backups-backblaze.service" ];
    serviceConfig = {
      User = "engineer";
      Group = "engineer";
      Type = "oneshot";
    };
    script = ''
      BACKUP_PATH="${backupRoot}/$(date +%Y%m%d-%H%M)"
      mkdir -p "$BACKUP_PATH"
      cp --reflink=always -r "${instance_dir}" "$BACKUP_PATH"
      echo "Backup done"
    '';
  };

  systemd.timers."se-local-backup" = {
    enable = true;
    description = "Run local backup of Space Engineers server regularly";
    wantedBy = [ "podman-${container-name}.service" ];
    partOf = [ "podman-${container-name}.service" ];
    timerConfig = {
      OnCalendar = "07/1:00";
      Unit = "se-local-backup.service";
      RandomisedDelaySec = 600;
    };
  };
}
