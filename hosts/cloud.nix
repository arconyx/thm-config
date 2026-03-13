{
  modulesPath,
  pkgs,
  lib,
  config,
  ...
}:
let
  uptime_kuma_port = 3001;
in
{
  imports = [ (modulesPath + "/virtualisation/google-compute-config.nix") ];

  # use lix
  nix.package = pkgs.lixPackageSets.latest.lix;
  nixpkgs.overlays = [
    (final: prev: {
      inherit (prev.lixPackageSets.latest)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena
        ;
    })
  ];

  boot.tmp.cleanOnBoot = true;

  users.users.arc = {
    enable = true;
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  programs = {
    fish.enable = true;
  };

  environment.systemPackages = [
    pkgs.helix
    pkgs.eza
  ];
  environment.sessionVariables.EDITOR = "hx";

  services = {
    uptime-kuma = {
      enable = true;
      settings = {
        UPTIME_KUMA_DB_TYPE = "sqlite";
        UPTIME_KUMA_PORT = builtins.toString uptime_kuma_port;
      };
    };

    tailscale = {
      enable = true;
      extraSetFlags = [ "--ssh --web-client" ];
      permitCertUid = lib.mkIf config.services.caddy.enable "caddy";
    };
  };

  nix = {
    settings = {
      allowed-users = [ "@wheel" ];
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc.automatic = true;
  };

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 2 * 1024; # 2GB
    }
  ];
  systemd.services.mkswap-var-swapfile.enableStrictShellChecks = false;

  nixpkgs.hostPlatform = {
    system = "x86_64-linux";
  };
  system.stateVersion = "25.11";
}
