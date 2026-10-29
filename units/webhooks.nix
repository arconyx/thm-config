{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.services.webhook.enable {
  systemd.services.webhook = {
    path = [ config.systemd.package ];

    serviceConfig = {
      RemoveIPC = true;
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateDevices = true;
      ProtectClock = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      PrivateMounts = true;
      SystemCallArchitectures = "native";
      MemoryDenyWriteExecute = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      ProtectHostname = true;
      LockPersonality = true;
      ProtectKernelTunables = true;
      RestrictRealtime = true;
      ProtectSystem = "strict";
      ProtectProc = "invisible";
      ProtectHome = true;
      PrivateUsers = true;
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
      SystemCallFilter = [
        "@system-service"
        "~@privileged @resources"
      ];
      RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
      PrivateNetwork = true;

      ReadWritePaths = [ "/run/dbus/system_bus_socket" ];
    };
  };

  systemd.services.proxy-webhook = {
    description = "Socket activiation proxy for the webhook service";
    requires = [
      "webhook.service"
      "proxy-webhook.socket"
    ];
    after = [
      "webhook.service"
      "proxy-webhook.socket"
    ];
    unitConfig.JoinsNamespaceOf = "webhook.service";
    serviceConfig = {
      Type = "notify";
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString config.services.webhook.port} --exit-idle-time 600";
      PrivateTmp = true;
      PrivateNetwork = true;
    };
  };

  systemd.sockets.proxy-webhook = {
    enable = true;
    description = "Public socket for the webhook service";
    listenStreams = [ "127.0.0.1:${toString config.services.webhook.port}" ];
    wantedBy = [ "sockets.target" ];
  };
}
