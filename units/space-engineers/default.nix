# Auto-generated using compose2nix v0.3.3-pre.
# TODO: Switch to rootless podman
{
  pkgs,
  lib,
  config,
  ...
}:

let
  default_world = ./inital_state;
  init-world = pkgs.writeShellScript "init-world" ''
    podman volume create spaceengineers_world
    tar cvf - --mode a=r,u+w,a+X -C ${default_world} . | podman volume import spaceengineers_world -
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
    home = "/var/lib/space-engineers";
    linger = true;
  };
  users.groups.engineer = { };

  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
  };

  # Enable container name DNS for all Podman networks.
  networking.firewall.interfaces =
    let
      matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
    in
    {
      "${matchAll}".allowedUDPPorts = [ 53 ];
    };

  networking.firewall.allowedUDPPorts = [ 25565 ];

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."space-engineers-dedicated-docker-linux" = {
    image = "mmmaxwwwell/space-engineers-dedicated-docker-linux:v2";
    volumes = [
      "spaceengineers_bins:/appdata/space-engineers/SpaceEngineersDedicated:rw"
      "spaceengineers_plugins:/appdata/space-engineers/Plugins:rw"
      "spaceengineers_steamcmd:/home/wine:rw"
      "spaceengineers_world:/appdata/space-engineers/World:rw"
    ];
    ports = [
      "25565:25565/udp"
    ];
    log-driver = "journald";
    podman.user = "engineer";
    extraOptions = [
      "--network-alias=se-server"
      "--network=bridge"
    ];
  };
  systemd.services."podman-space-engineers-dedicated-docker-linux" = {
    startLimitIntervalSec = 300;
    startLimitBurst = 5;
    serviceConfig = {
      Restart = lib.mkOverride 90 "on-failure";
    };
    after = [
      "podman-volume-spaceengineers_bins.service"
      "podman-volume-spaceengineers_plugins.service"
      "podman-volume-spaceengineers_steamcmd.service"
      "podman-volume-spaceengineers_world.service"
    ];
    requires = [
      "podman-volume-spaceengineers_bins.service"
      "podman-volume-spaceengineers_plugins.service"
      "podman-volume-spaceengineers_steamcmd.service"
      "podman-volume-spaceengineers_world.service"
    ];
    partOf = [
      "podman-compose-spaceengineers-root.target"
    ];
    wantedBy = [
      "podman-compose-spaceengineers-root.target"
    ];
    # TODO: Replace with something that blocks se startup rather than terminating the mc server
    conflicts = [ "minecraft-server-magic.service" ];
  };

  # Volumes
  systemd.services."podman-volume-spaceengineers_bins" = {
    path = [
      pkgs.podman
      # Needed for access to newuidmap from pkgs.shadow with setcap binaries
      "/run/wrappers"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "engineer";
    };
    script = ''
      podman volume inspect spaceengineers_bins || podman volume create spaceengineers_bins
    '';
    partOf = [ "podman-compose-spaceengineers-root.target" ];
    wantedBy = [ "podman-compose-spaceengineers-root.target" ];
  };
  systemd.services."podman-volume-spaceengineers_plugins" = {
    path = [
      pkgs.podman
      "/run/wrappers"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "engineer";
    };
    script = ''
      podman volume inspect spaceengineers_plugins || podman volume create spaceengineers_plugins
    '';
    partOf = [ "podman-compose-spaceengineers-root.target" ];
    wantedBy = [ "podman-compose-spaceengineers-root.target" ];
  };
  systemd.services."podman-volume-spaceengineers_steamcmd" = {
    path = [
      pkgs.podman
      "/run/wrappers"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "engineer";
    };
    script = ''
      podman volume inspect spaceengineers_steamcmd || podman volume create spaceengineers_steamcmd
    '';
    partOf = [ "podman-compose-spaceengineers-root.target" ];
    wantedBy = [ "podman-compose-spaceengineers-root.target" ];
  };
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

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-spaceengineers-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    # wantedBy = [ "multi-user.target" ];
  };

  arcworks.services.backups.backup.backblaze.paths = [
    "${config.users.users.engineer.home}/.local/share/containers/storage/volumes/spaceengineers_world/_data"
  ];
}
