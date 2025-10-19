# Auto-generated using compose2nix v0.3.3-pre.
# TODO: Switch to rootless podman
{
  pkgs,
  config,
  lib,
  ...
}:

let
  default_world = ./inital_state;
  home = "/var/lib/space-engineers";
  world_host_dir = "${home}/se_world";
  init-world = pkgs.writeShellScript "init-world" ''
    if [! -d "${world_host_dir}" ]; then
      mkdir "${world_host_dir}"
      install --backup numbered --mode a=rX,u+w "${default_world}" "${world_host_dir}"
    fi
    cp --update all "${default_world}/SpaceEngineers-Dedicated.cfg" "${world_host_dir}"
    chmod --mode a=rX,u+w "${world_host_dir}/SpaceEngineers-Dedicated.cfg"
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
    { ... }:
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

  arcworks.services.backups.backup.backblaze.paths = [
    "${config.users.users.engineer.home}/.local/share/containers/storage/volumes/spaceengineers_world/_data"
  ];
}
