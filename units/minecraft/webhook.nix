{
  pkgs,
  config,
  lib,
  ...
}:
let
  utils = import ./utils.nix { inherit config lib; };

in
{
  # Register a webhook to start the minecraft server
  services.webhook = {
    enable = true;
    # bind to loopback only
    # we're not opening the firewall, but better safe
    ip = "127.0.0.1";
    verbose = true;
    hooks = utils.forEachServer (
      name: cfg: {
        minecraft = {
          id = "start-mc-${name}";
          execute-command = "${pkgs.systemd}/bin/systemctl";
          pass-arguments-to-command = [
            {
              source = "string";
              name = "start";
            }
            {
              source = "string";
              name = "notify-minecraft-server-unavailable-${name}.service";
            }
          ];
        };
      }
    );
  };

  # Use polkit to give the webhooks user permission to start the service
  security.polkit = {
    enable = true;
    extraConfig = lib.concatLines (
      utils.forEachServerName (name: ''
        /* Allow webhooks to launch Minecraft */
        polkit.addRule(function(action, subject) {
          if (
            action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "minecraft-server-${name}.service" &&
            subject.user == "${config.services.webhook.user}" &&
            action.lookup("verb") == "start"
          ) {
            return polkit.Result.YES;
          }
        });
      '')
    );
  };
}
