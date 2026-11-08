{
  lib,
  ...
}:

{
  boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "ext4"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
