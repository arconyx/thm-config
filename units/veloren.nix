{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.thm.services.veloren;
in
{
  options.thm.services.veloren = {
    enable = lib.mkEnableOption "Veloren server";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.veloren = {
      description = "Veloren server";
      after = [ "network.target" ];
      conflicts = [ "gate.service" ];

      environment = {
        VELOREN_USERDATA = "%S/veloren";
      };

      serviceConfig = {
        ExecStart = lib.getExe' pkgs.veloren "veloren-server-cli";
        Type = "exec";

        Restart = "on-failure";

        User = "veloren";
        DynamicUser = true;

        StateDirectory = "veloren";
        # WorkingDirectory = "%S/veloren";

        MemoryHigh = "8G";
        MemoryMax = "10G";

        ProtectProc = "invisible";
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateIPC = true;
        PrivateUsers = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = "strict";
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        RestrictNamespaces = true;
        PrivateBPF = true;
        LockPersonality = true;
        RestrictSUIDSGID = true;
        PrivateMounts = true;
        SystemCallFilter = "~@privileged";
      };

      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };
    };
  };
}
