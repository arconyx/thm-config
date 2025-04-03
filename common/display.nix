{ ... }:

{
  # opengl is also enabled in nvidia.nix
  hardware.graphics.enable = true;

  # Flag that we're running under wayland
  # Used for electron apps and stuff
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Helpful for investigating graphics stuff
  # Don't forget to add pkgs back to the inputs
  # environment.systemPackages = with pkgs; [
  #   clinfo
  #   glxinfo
  #   wayland-utils
  #   vulkan-tools
  # ];

}
