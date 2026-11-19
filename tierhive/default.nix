{ ... }: {
  imports = [
    ./backup.nix
    ./cloudinit.nix
    ./hardware.nix
    ./network.nix
    ./nix.nix
    ./shrink-closure.nix
    ./tierhive.nix
  ];
}
