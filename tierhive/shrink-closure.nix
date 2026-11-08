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

  # don't care about any of this
  boot.enableContainers = false;
  programs.command-not-found.enable = lib.mkForce false;
  services.udisks2.enable = false;

  # desktop stuff we don't care about on a headless machine
  xdg.autostart.enable = false;

  # Only use root
  security.sudo.enable = false;
}
