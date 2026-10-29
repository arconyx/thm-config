{ config, lib, ... }:
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
      SystemCallFilter = ["@system-service" "~@privileged @resources"];
      RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";

      ReadWritePaths = [ "/run/dbus/system_bus_socket" ];
    };
  };
}
