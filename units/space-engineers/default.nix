{ lib, ... }:

let
  default_world = ./inital_state;
  home = "/var/lib/space-engineers";
  world_host_dir = "${home}/se_world";
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

  home-manager.users.engineer =
    let
      container-name = "space-engineers";
    in
    {
      home.stateVersion = "25.05";
      home.homeDirectory = home;

      services.podman = {
        enable = true;
        volumes = {
          spaceengineers_bins = {
            description = "Binaries for Space Engineers";
            driver = "local";
            preserve = false;
          };
          spaceengineers_plugins = {
            description = "Plugins for Space Engineers";
            driver = "local";
            preserve = false;
          };
          spaceengineers_steamcmd = {
            description = "Steam CLI for Space Engineers";
            driver = "local";
            preserve = false;
          };
        };

        containers."${container-name}" = {
          autoStart = false;
          description = "Space Engineers server";
          image = "mmmaxwwwell/space-engineers-dedicated-docker-linux:v2";
          network = "bridge";
          networkAlias = [ "se-server" ];
          ports = [ "25565:25565/udp" ];
          volumes = [
            "spaceengineers_bins:/appdata/space-engineers/SpaceEngineersDedicated:rw"
            "spaceengineers_plugins:/appdata/space-engineers/Plugins:rw"
            "spaceengineers_steamcmd:/home/wine:rw"
            "${world_host_dir}:/appdata/space-engineers/World:rw"
          ];
          userNS = "keep-id:uid=1000,gid=1000";
        };
      };

      systemd.user.services.init-se-world = {
        enable = true;
        script = ''
          set -eo pipefail
          mkdir -p "${world_host_dir}" $VERBOSE_ARG
          if [ ! -d "${world_host_dir}/World" ]; then
            cp -r --update=none $VERBOSE_ARG "${default_world}/World" "${world_host_dir}"
          fi
          cp --update=all $VERBOSE_ARG "${default_world}/SpaceEngineers-Dedicated.cfg" "${world_host_dir}"
          chmod -R a=rX,u+w $VERBOSE_ARG "${world_host_dir}"
        '';
        requiredBy = [ "podman-${container-name}.service" ];
        before = [ "podman-${container-name}.service" ];
      };

    };

  networking.firewall.allowedUDPPorts = [ 25565 ];

  arcworks.services.backups.backup.backblaze.paths = [ world_host_dir ];
}
