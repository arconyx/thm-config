{
  lib,
  ...
}:

{
  nixpkgs.overlays = [
    (self: super: {
      # No display to care about x11
      dbus = super.dbus.override { x11Support = false; };
      systemd = super.systemd.override {
        # No UEFI support
        withEfi = false;
        # No tpm2 to use
        withTpm2Tss = false;

        # not used
        withCryptsetup = false;
        withRepart = false;
        withFido2 = false;
        withHomed = false;
        withRemote = false;
      };
    })
  ];

  # We don't need sudo if we only use root
  security.sudo.enable = false;
  security.pam.services.su.forwardXAuth = lib.mkForce false;

  environment.defaultPackages = [ ];
  xdg = {
    mime.enable = false;
    icons.enable = false;
    sounds.enable = false;
  };
  fonts.fontconfig.enable = false;
  services.lvm.enable = false;
  boot.bcache.enable = false;
  services.udisks2.enable = false;
  boot.enableContainers = false;
  programs.command-not-found.enable = lib.mkForce false;

  systemd.suppressedSystemUnits = [
    "systemd-importd.service"
    "sys-kernel-config.mount"
  ];

  system.tools = {
    nixos-option.enable = false;
    nixos-build-vms.enable = false;
    nixos-install.enable = false;
    nixos-enter.enable = false;
  };

  documentation = {
    enable = false;
    man.enable = false;
    nixos.enable = false;
  };
}
