{ ... }:

{
  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    editor = false;
    consoleMode = "max";
  };

  boot.loader.efi.canTouchEfiVariables = true;
}
