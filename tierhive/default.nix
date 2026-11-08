{ pkgs, ... }: {
  imports = [
    ./hardware.nix
    ./tierhive.nix
  ];

  environment.systemPackages = with pkgs; [
    curl
    rsync
  ];

  system.stateVersion = "26.05";
}
