{ pkgs, ... }: {
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      datasource_list = [ "NoCloud" ];
      system_info = {
        distro = "nixos";
        network.renderers = [ "networkd" ];
        paths.templates_dir = "${pkgs.cloud-init}/${pkgs.python3.sitePackages}/etc/cloud/templates";
      };
      ssh_deletekeys = false;
      ssh_genkeytypes = [ ];
      cloud_init_modules = [
        "seed_random"
        "bootcmd"
        "write_files"
        "growpart"
        "resizefs"
        "set_hostname"
        "update_hostname"
        "update_etc_hosts"
        "users_groups"
        "ssh"
      ];
      cloud_config_modules = [
        "set_passwords"
        "runcmd"
      ];
      cloud_final_modules = [
        "package_update_upgrade_install"
        "write_files_deferred"
        "scripts_vendor"
        "scripts_per_once"
        "scripts_per_boot"
        "scripts_per_instance"
        "scripts_user"
        "keys_to_console"
        "final_message"
      ];
    };
  };
  systemd.services.cloud-init-local.unitConfig.ConditionPathExists =
    "!/etc/cloud/cloud-init.disabled";
  systemd.services.cloud-init.unitConfig.ConditionPathExists = "!/etc/cloud/cloud-init.disabled";
  systemd.services.cloud-config.unitConfig.ConditionPathExists = "!/etc/cloud/cloud-init.disabled";
  systemd.services.cloud-final.unitConfig.ConditionPathExists = "!/etc/cloud/cloud-init.disabled";

  systemd.services.tierhive-lldp-off = {
    description = "Disable LLDP reception on the cloud-init network files";
    unitConfig.DefaultDependencies = false;
    after = [ "cloud-init-local.service" ];
    before = [ "systemd-networkd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for f in /etc/systemd/network/10-cloud-init-*.network; do
        [ -e "$f" ] || continue
        [ -e "$f.d/10-tierhive-lldp.conf" ] && continue
        mkdir -p "$f.d"
        printf '[Network]\nLLDP=no\n' > "$f.d/10-tierhive-lldp.conf"
      done
    '';
  };

  systemd.services.tierhive-reserved-blocks = {
    description = "Set root fs reserved blocks to 0.01% after first-boot grow";
    wantedBy = [ "multi-user.target" ];
    after = [ "cloud-init.service" ];
    unitConfig.ConditionPathExists = "!/var/lib/tierhive/reserved-blocks.done";
    path = [
      pkgs.e2fsprogs
      pkgs.util-linux
      pkgs.gawk
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      dev=$(findmnt -no SOURCE /)
      blocks=$(tune2fs -l "$dev" | awk -F: '/^Block count/{gsub(/ /,"",$2); print $2}')
      tune2fs -r $((blocks / 10000)) "$dev"
      mkdir -p /var/lib/tierhive
      touch /var/lib/tierhive/reserved-blocks.done
    '';
  };
}
