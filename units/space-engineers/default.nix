# Auto-generated using compose2nix v0.3.3-pre.
# TODO: Switch to rootless podman
{
  pkgs,
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

  home-manager.users.engineer =
    { osConfig, ... }:
    {
      home.stateVersion = "25.05";
      home.homeDirectory = osConfig.users.users.engineer.home;

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
          spaceengineers_world = {
            description = "World save for Space Engineers";
            driver = "local";
            preserve = true;
          };
        };

        containers."space-engineers-dedicated-docker-linux" = {
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
            "spaceengineers_world:/appdata/space-engineers/World:rw"
          ];
        };
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

  arcworks.services.backups.backup.backblaze.paths = [
    "${config.users.users.engineer.home}/.local/share/containers/storage/volumes/spaceengineers_world/_data"
  ];
}
