{
  config,
  lib,
  pkgs,
  ...
}:
let
  mcCfg = config.thm.services.minecraft;
  datapackServers = lib.filterAttrs (_: cfg: cfg.enable && cfg.importDatapacks.enable) mcCfg.servers;
  useDatapacks = mcCfg.enable && datapackServers != { };
  mkServiceName = name: "update-datapacks-${name}";
in
{
  config = lib.mkIf useDatapacks {
    # allow updating servers with a webhook
    services.webhook = {
      enable = true;
      hooks = lib.concatMapAttrs (
        name: cfg:
        let
          update-datapacks = pkgs.writeShellScript "start-datapack-update-from-webhook-${name}" ''
            systemctl start ${mkServiceName name}.service
          '';
        in
        {
          "minecraft-update-datapacks-${name}" = {
            id = "update-mc-${name}";
            execute-command = "${update-datapacks}";
          };
        }
      ) datapackServers;
    };
    # Use polkit to give the webhooks user permission to start the service
    security.polkit = {
      enable = true;
      extraConfig = lib.concatLines (
        [ "/* Allow webhooks to launch Minecraft */" ]
        ++ (lib.mapAttrsToList (name: cfg: ''
          polkit.addRule(function(action, subject) {
            if (
              action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "${mkServiceName name}.service" &&
              subject.user == "${config.services.webhook.user}" &&
              action.lookup("verb") == "start"
            ) {
              return polkit.Result.YES;
            }
          });
        '') datapackServers)
      );
    };

    systemd.services = {
      # access to env file for discord token
      webhook.serviceConfig = {
        SupplementaryGroups = [ "minecraft" ];
      };
    }
    // (lib.concatMapAttrs (name: cfg: {
      # if no player is connected wait a minute
      # if still no players, shutdown the server
      "${mkServiceName name}" = {
        enable = true;
        serviceConfig = {
          User = config.services.minecraft-servers.user;
          Group = config.services.minecraft-servers.group;
          Type = "oneshot";
        };
        script =
          let
            dpCfg = cfg.importDatapacks;
            msg-discord = msg: ''
              ${lib.getExe pkgs.curl} -F username=${config.networking.hostName} -F content="[${name}] ${msg}" "$DISCORD_WEBHOOK_URL"
            '';
            data_dir = name: config.systemd.services."minecraft-server-${name}".serviceConfig.WorkingDirectory;
            zip-pack = folder: ''
              (cd "$GIT_DIR/${folder}" && ${lib.getExe pkgs.zip} -r "$BUILD_DIR/${folder}.zip" .)
            '';
          in
          ''
            set -euxo pipefail

            WORKING_DIR=$(mktemp -d)
            GIT_DIR="$WORKING_DIR/git"
            BUILD_DIR="$WORKING_DIR/build"
            mkdir "$GIT_DIR"
            mkdir "$BUILD_DIR"

            ${lib.getExe pkgs.git} clone --depth 1 "${dpCfg.repository}" "$GIT_DIR"

            ${lib.concatLines (builtins.map zip-pack dpCfg.directories)}

            cp --update=all "$BUILD_DIR/"*.zip "${data_dir name}/world/datapacks"

            ${msg-discord "Datapacks updated from git repo. \`/reload\` required to apply changes."}
          '';
      };
    }) datapackServers);
  };
}
