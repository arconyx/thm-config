{ pkgs, lib, ... }:

let
  default_world = ./inital_state;
  home = "/var/lib/space-engineers";
  world_host_dir = "${home}/se_world";
  init-world = pkgs.writeShellScript "init-world" ''
    set -eo pipefail
    mkdir -p "${world_host_dir}"
    if [ ! -d "${world_host_dir}/World" ]; then
      cp -r --update=none "${default_world}/World" "${world_host_dir}"
    fi
    cp --update=all "${default_world}/SpaceEngineers-Dedicated.cfg" "${world_host_dir}"
    chmod -R a=rX,u+w "${world_host_dir}"
  '';
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

      systemd.user.services.pod-unifi = {

        Service = {
          Type = "forking";
          ExecStartPre = [
            # This is needed for the Pod start automatically
            "${pkgs.coreutils}/bin/sleep 3s"
            # Port config see:
            # https://help.ui.com/hc/en-us/articles/218506997-Required-Ports-Reference
            # The image requires `--userns=host`
            ''
              -${pkgs.podman}/bin/podman pod create --replace \
                --network=unifi \
                --userns=host \
                --cpus=3 \
                --label=PODMAN_SYSTEMD_UNIT="pod-unifi.service" \
                -p 192.168.3.1:8443:8443/tcp \
                -p 192.168.4.1:1900:1900/udp \
                -p 192.168.4.1:3478:3478/udp \
                -p 192.168.4.1:5514:5514/udp \
                -p 192.168.4.1:10001:10001/udp \
                -p 192.168.4.1:6789:6789/tcp \
                -p 192.168.4.1:8080:8080/tcp unifi
            ''
          ]; # ExecStartPre
          ExecStart = "${pkgs.podman}/bin/podman pod start unifi";
          ExecStop = "${pkgs.podman}/bin/podman pod stop unifi";
          RestartSec = "1s";
        }; # Service
      }; # systemd.user.services.pod-unifi

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

  arcworks.services.backups.backup.backblaze.paths = [ world_host_dir ];
}
