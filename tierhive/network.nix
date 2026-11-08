{ ... }: {
  networking = {
    hostName = "";
    useDHCP = false;
    resolvconf.enable = false;
  };
  services.resolved.enable = false;
  environment.etc."resolv.conf".text = ''
    # tailscale DNS won't work
    nameserver 1.1.1.1
    nameserver 1.0.0.1
  '';

  services.openssh.enable = false;
  services.tailscale = {
    enable = true;
    disableTaildrop = true;
    disableUpstreamLogging = true;
    extraSetFlags = [
      "--ssh"
      "--accept-dns=false"
    ];
  };
  systemd.services.tailscaled.environment.GOGC = "10";

}
