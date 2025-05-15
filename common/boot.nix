{ ... }:

{
  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    editor = false;
    consoleMode = "max";
  };

  boot.loader.efi.canTouchEfiVariables = true;

  # reboot after one second when kernel panics
  boot.kernelParams = [ "panic=1" ];
}
