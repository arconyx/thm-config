# TierHive VPS platform settings: network, DNS and hostname come from the panel via cloud-init on first boot.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Kernel module tree without drivers for hardware a KVM VPS never has; kept modules always keep their dependencies.
  kernel = config.boot.kernelPackages.kernel;
  moduleTreeRemove = [
    "kernel/sound/*"
    "kernel/drivers/accel/*"
    "kernel/drivers/accessibility/*"
    "kernel/drivers/atm/*"
    "kernel/drivers/auxdisplay/*"
    "kernel/drivers/bcma/*"
    "kernel/drivers/bluetooth/*"
    "kernel/drivers/bus/*"
    "kernel/drivers/clk/*"
    "kernel/drivers/comedi/*"
    "kernel/drivers/counter/*"
    "kernel/drivers/cpufreq/*"
    "kernel/drivers/crypto/*"
    "kernel/drivers/cxl/*"
    "kernel/drivers/dca/*"
    "kernel/drivers/devfreq/*"
    "kernel/drivers/dma/*"
    "kernel/drivers/edac/*"
    "kernel/drivers/extcon/*"
    "kernel/drivers/firewire/*"
    "kernel/drivers/fpga/*"
    "kernel/drivers/fsi/*"
    "kernel/drivers/fwctl/*"
    "kernel/drivers/gnss/*"
    "kernel/drivers/gpio/*"
    "kernel/drivers/greybus/*"
    "kernel/drivers/hid/*"
    "kernel/drivers/hsi/*"
    "kernel/drivers/hv/*"
    "kernel/drivers/hwmon/*"
    "kernel/drivers/hwtracing/*"
    "kernel/drivers/i2c/*"
    "kernel/drivers/i3c/*"
    "kernel/drivers/iio/*"
    "kernel/drivers/infiniband/hw/*"
    "kernel/drivers/ipack/*"
    "kernel/drivers/leds/*"
    "kernel/drivers/macintosh/*"
    "kernel/drivers/mailbox/*"
    "kernel/drivers/mcb/*"
    "kernel/drivers/media/*"
    "kernel/drivers/memstick/*"
    "kernel/drivers/message/*"
    "kernel/drivers/mfd/*"
    "kernel/drivers/mmc/*"
    "kernel/drivers/most/*"
    "kernel/drivers/mtd/*"
    "kernel/drivers/mux/*"
    "kernel/drivers/nfc/*"
    "kernel/drivers/ntb/*"
    "kernel/drivers/nvdimm/*"
    "kernel/drivers/nvmem/*"
    "kernel/drivers/parport/*"
    "kernel/drivers/pcmcia/*"
    "kernel/drivers/peci/*"
    "kernel/drivers/perf/*"
    "kernel/drivers/phy/*"
    "kernel/drivers/pinctrl/*"
    "kernel/drivers/platform/*"
    "kernel/drivers/power/*"
    "kernel/drivers/powercap/*"
    "kernel/drivers/rapidio/*"
    "kernel/drivers/ras/*"
    "kernel/drivers/regulator/*"
    "kernel/drivers/reset/*"
    "kernel/drivers/rpmsg/*"
    "kernel/drivers/siox/*"
    "kernel/drivers/slimbus/*"
    "kernel/drivers/soc/*"
    "kernel/drivers/soundwire/*"
    "kernel/drivers/spi/*"
    "kernel/drivers/spmi/*"
    "kernel/drivers/ssb/*"
    "kernel/drivers/staging/*"
    "kernel/drivers/tee/*"
    "kernel/drivers/thermal/*"
    "kernel/drivers/thunderbolt/*"
    "kernel/drivers/ufs/*"
    "kernel/drivers/usb/*"
    "kernel/drivers/w1/*"
    "kernel/drivers/xen/*"
    "kernel/drivers/video/fbdev/*"
    "kernel/drivers/video/backlight/*"
    "kernel/drivers/gpu/drm/*/*"
    "kernel/drivers/input/joystick/*"
    "kernel/drivers/input/touchscreen/*"
    "kernel/drivers/input/tablet/*"
    "kernel/drivers/input/gameport/*"
    "kernel/drivers/input/rmi4/*"
    "kernel/drivers/net/ethernet/*"
    "kernel/drivers/net/wireless/*"
    "kernel/drivers/net/wwan/*"
    "kernel/drivers/net/usb/*"
    "kernel/drivers/net/arcnet/*"
    "kernel/drivers/net/fddi/*"
    "kernel/drivers/net/hamradio/*"
    "kernel/drivers/net/hippi/*"
    "kernel/drivers/net/ieee802154/*"
    "kernel/drivers/net/wan/*"
    "kernel/drivers/net/plip/*"
    "kernel/drivers/net/fjes/*"
    "kernel/drivers/net/hyperv/*"
    "kernel/drivers/net/vmxnet3/*"
    "kernel/drivers/net/xen-netback/*"
    "kernel/drivers/net/xen-netfront.ko*"
    "kernel/drivers/net/thunderbolt/*"
    "kernel/drivers/net/mhi_net.ko*"
    "kernel/drivers/net/dsa/*"
    "kernel/drivers/net/rionet.ko*"
    "kernel/drivers/net/ntb_netdev.ko*"
    "kernel/drivers/net/sungem_phy.ko*"
    "kernel/drivers/block/floppy.ko*"
    "kernel/drivers/block/mtip32xx/*"
    "kernel/drivers/block/xen-blk*"
    "kernel/drivers/scsi/*"
    "kernel/drivers/ata/*"
    "kernel/drivers/watchdog/*"
    "kernel/drivers/rtc/*"
  ];
  moduleTreeKeep = [
    "kernel/drivers/gpu/drm/virtio/*"
    "kernel/drivers/scsi/scsi_mod.ko*"
    "kernel/drivers/scsi/scsi_common.ko*"
    "kernel/drivers/scsi/sd_mod.ko*"
    "kernel/drivers/scsi/sr_mod.ko*"
    "kernel/drivers/scsi/sg.ko*"
    "kernel/drivers/scsi/st.ko*"
    "kernel/drivers/scsi/ch.ko*"
    "kernel/drivers/scsi/ses.ko*"
    "kernel/drivers/scsi/raid_class.ko*"
    "kernel/drivers/scsi/virtio_scsi.ko*"
    "kernel/drivers/scsi/scsi_transport_*"
    "kernel/drivers/scsi/iscsi_tcp.ko*"
    "kernel/drivers/scsi/libiscsi.ko*"
    "kernel/drivers/scsi/libiscsi_tcp.ko*"
    "kernel/drivers/scsi/iscsi_boot_sysfs.ko*"
    "kernel/drivers/ata/libata.ko*"
    "kernel/drivers/ata/ata_piix.ko*"
    "kernel/drivers/ata/ahci.ko*"
    "kernel/drivers/ata/libahci.ko*"
    "kernel/drivers/watchdog/watchdog.ko*"
    "kernel/drivers/watchdog/i6300esb.ko*"
    "kernel/drivers/watchdog/softdog.ko*"
    "kernel/drivers/rtc/rtc-cmos.ko*"
  ];
  modulesSrc = lib.getOutput "modules" kernel;
  trimmedModules =
    pkgs.runCommand "${kernel.name}-modules-tierhive" { nativeBuildInputs = [ pkgs.kmod ]; }
      ''
        set -f
        remove="${lib.concatStringsSep " " moduleTreeRemove}"
        keep="${lib.concatStringsSep " " moduleTreeKeep}"
        ver=$(ls ${modulesSrc}/lib/modules)
        src=${modulesSrc}/lib/modules/$ver
        dst=$out/lib/modules/$ver
        match() { local f=$1 p; for p in $2; do case $f in $p) return 0;; esac; done; return 1; }
        declare -A want
        while IFS= read -r line; do
          m=''${line%%:*}
          if match "$m" "$remove" && ! match "$m" "$keep"; then continue; fi
          want[$m]=1
          for d in ''${line#*:}; do want[$d]=1; done
        done < $src/modules.dep
        for m in "''${!want[@]}"; do mkdir -p "$dst/$(dirname "$m")"; cp "$src/$m" "$dst/$m"; done
        cp $src/modules.builtin $src/modules.builtin.modinfo $dst/
        while IFS= read -r o; do
          for m in "$o" "$o.xz" "$o.zst" "$o.gz"; do [ -n "''${want[$m]:-}" ] && { echo "$o"; break; }; done
        done < $src/modules.order > $dst/modules.order
        depmod -b $out -a $ver
      '';
in
{
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  boot.kernelParams = [
    "sysctl.vm.mem_profiling=never"
    "damon_stat.enabled=N"
    "kfence.sample_interval=0"
    "audit=0"
    "initcall_blacklist=ksm_init,tpm_init,init_tis"
    "psi=0"
    "ras=cec_disable"
    "nowatchdog"
    "nmi_watchdog=0"
    "cryptomgr.notests"
    "8250.nr_uarts=1"
    "transparent_hugepage=never"
  ];
  system.modulesTree = lib.mkForce ([ trimmedModules ] ++ config.boot.extraModulePackages);
  boot.blacklistedKernelModules = [
    "virtio_console"
    "floppy"
    "intel_agp"
    "i2c_piix4"
    "psmouse"
    "mousedev"
    "joydev"
    "serio_raw"
    "mac_hid"
    "input_leds"
    "evdev"
    "button"
    "rapl"
    "intel_rapl_msr"
    "intel_rapl_common"
    "intel_cstate"
    "intel_uncore"
    "kvm_intel"
    "kvm_amd"
    "kvm"
    "cfg80211"
    "ata_generic"
    "pata_acpi"
    "qemu_fw_cfg"
    "dmi_sysfs"
    "vga16fb"
    "virtio_gpu"
  ];
  boot.extraModprobeConfig = lib.concatMapStrings (m: "install ${m} ${pkgs.coreutils}/bin/false\n") [
    "vsock"
    "vmw_vsock_virtio_transport"
    "vsock_loopback"
    "vmw_vsock_vmci_transport"
    "vmw_vmci"
    "virtiofs"
  ];

  boot.kernel.sysctl = {
    "kernel.panic_on_oops" = 1;
    "kernel.panic" = 10;
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.watermark_boost_factor" = 0;
  };

  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="vd[a-z]*", ENV{DEVTYPE}=="disk", ATTR{queue/scheduler}="none", ATTR{queue/read_ahead_kb}="128"
  '';

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    memoryMax = 536870912;
  };

  systemd.oomd.enable = false;

  services.timesyncd.enable = false;
  systemd.services.tierhive-ntp = {
    description = "One-shot clock sync";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.busybox}/bin/ntpd -n -q ${
      lib.concatMapStringsSep " " (s: "-p ${s}") config.networking.timeServers
    }";
  };
  systemd.timers.tierhive-ntp = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "30s";
    timerConfig.OnCalendar = "*-*-* *:17:00";
  };

  environment.etc."systemd/journald.conf.d/10-tierhive.conf".text = ''
    [Journal]
    SystemMaxUse=50M
  '';

  environment.variables = {
    GC_INITIAL_HEAP_SIZE = "33554432";
    GC_FREE_SPACE_DIVISOR = "8";
    GC_FORCE_UNMAP_ON_GCOLLECT = "1";
  };

  environment.defaultPackages = [ ];
  xdg.mime.enable = false;
  xdg.icons.enable = false;
  xdg.sounds.enable = false;
  fonts.fontconfig.enable = false;
  services.lvm.enable = false;
  boot.bcache.enable = false;
  systemd.suppressedSystemUnits = [
    "systemd-importd.service"
    "sys-kernel-config.mount"
  ];
  system.tools.nixos-option.enable = false;
  system.tools.nixos-build-vms.enable = false;
  system.tools.nixos-install.enable = false;
  system.tools.nixos-enter.enable = false;
  security.pam.services.su.forwardXAuth = lib.mkForce false;

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    settings.PermitRootLogin = null;
    settings.PasswordAuthentication = null;
    settings.KbdInteractiveAuthentication = false;
    extraConfig = "Include /etc/ssh/sshd_config.d/*.conf";
  };
  security.pam.services.sshd.unixAuth = lib.mkForce true;
  systemd.tmpfiles.rules = [ "d /etc/ssh/sshd_config.d 0755 root root -" ];

  environment.etc.fstab.mode = "0644";
}
