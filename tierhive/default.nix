{ pkgs, ... }: {
  imports = [
    ./cloudinit.nix
    ./hardware.nix
    ./network.nix
    ./nix.nix
    ./tierhive.nix
  ];

  environment.systemPackages = with pkgs; [
    curl
    rsync
  ];

  system.stateVersion = "26.05";
}
