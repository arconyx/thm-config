{ ... }:

{
  imports = [
    ./../common.nix

    ./hardware-configuration.nix
    ./networking.nix
    ./minecraft
  ];

  arcworks.server.enable = true;

  arcworks.users.fishynz = {
    enable = true;
    description = "fishynz";
  };

  networking.hostName = "hive"; # Define your hostname.

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "nz";
    variant = "";
  };

  services.minecraft-servers.servers.magic.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
