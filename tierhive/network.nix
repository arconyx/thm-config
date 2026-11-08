{ ... }: {
  networking = {
    hostName = "";
    useDHCP = false;
    resolvconf.enable = false;
  };
  services.resolved.enable = false;
  environment.etc."resolv.conf".text = ''
    nameserver 1.1.1.1
    nameserver 1.0.0.1
  '';
}
