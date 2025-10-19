# Auto-generated using compose2nix v0.3.3-pre.
# TODO: Switch to rootless podman
{
  pkgs,
  lib,
  ...
}:

let
  default_world = ./inital_state;
  home = "/var/lib/space-engineers";
  world_host_dir = "${home}/se_world";
  init-world = pkgs.writeShellScript "init-world" ''
    set -eo pipefail
    mkdir -p "${world_host_dir}" $VERBOSE_ARG
    if [ ! -d "${world_host_dir}/World" ]; then
      cp -r --update=none $VERBOSE_ARG "${default_world}/World" "${world_host_dir}"
    fi
    cp --update=all $VERBOSE_ARG "${default_world}/SpaceEngineers-Dedicated.cfg" "${world_host_dir}"
    chmod -R a=rX,u+w $VERBOSE_ARG "${world_host_dir}"
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
    { lib, ... }:
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

        containers."space-engineers" = {
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
        };
      };

      home.activation = {
        initSEWorld = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${init-world}
        '';
      };
    };

  # virtualisation = {
  #   containers.enable = true;
  #   podman = {
  #     enable = true;
  #     autoPrune.enable = true;
  #     # defaultNetwork.settings.dns_enabled = true;
  #   };
  #   oci-containers.backend = "podman";
  # };

  # # Enable container name DNS for all Podman networks.
  # networking.firewall.interfaces =
  #   let
  #     matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  #   in
  #   {
  #     "${matchAll}".allowedUDPPorts = [ 53 ];
  #   };

  networking.firewall.allowedUDPPorts = [ 25565 ];

  systemd.services."podman-volume-spaceengineers_world" = {
    path = [
      pkgs.podman
      "/run/wrappers"
      pkgs.gnutar
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "engineer";
    };
    script = ''
      podman volume inspect spaceengineers_world || ${init-world}
    '';
    partOf = [ "podman-compose-spaceengineers-root.target" ];
    wantedBy = [ "podman-compose-spaceengineers-root.target" ];
  };

  arcworks.services.backups.backup.backblaze.paths = [ world_host_dir ];
}
