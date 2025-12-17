{ config, ... }:
{
  imports = [
    ./servers/magic.nix
    ./servers/forever-test.nix
  ];

  # allow easy interaction with world save
  users.users.arc.extraGroups = [ "minecraft" ];

  # Configure backups
  arcworks.services.backups.global = {
    paths = [
      "/etc/cloudflare"
      "/etc/minecraft"
      # /srv/minecraft already added by top level conf including all of /srv
    ];
  };

  # keep dns fresh for server subdomain
  services.cloudflare-dyndns = {
    enable = true;
    frequency = "*:0/15";
    # subdomains of this are handled with a cname atm
    domains = [ "mc.thehivemind.gay" ];
    proxied = false; # no point trying to proxy minecraft
    deleteMissing = false;
    apiTokenFile = "/etc/cloudflare/apikey.env";
  };

  thm.services.minecraft = {
    enable = true;
    environmentFile = "/etc/minecraft/magic.env";
    rcon-password = "3489trawo5ATpfhaQEQr"; # pragma: allowlist secret
    jvmOpts = [
      "-Xms8G"
      "-Xmx8G"
      "-XX:+UnlockExperimentalVMOptions"
      "-XX:+UnlockDiagnosticVMOptions"
      "-XX:+AlwaysActAsServerClassMachine"
      "-XX:+AlwaysPreTouch"
      "-XX:+DisableExplicitGC"
      "-XX:+UseNUMA"
      "-XX:AllocatePrefetchStyle=3"
      "-XX:NmethodSweepActivity=1"
      "-XX:ReservedCodeCacheSize=400M"
      "-XX:NonNMethodCodeHeapSize=12M"
      "-XX:ProfiledCodeHeapSize=194M"
      "-XX:NonProfiledCodeHeapSize=194M"
      "-XX:-DontCompileHugeMethods"
      "-XX:+PerfDisableSharedMem"
      "-XX:+UseFastUnorderedTimeStamps"
      "-XX:+UseCriticalJavaThreadPriority"
      "-XX:+EagerJVMCI"
      "-Dgraal.TuneInlinerExploration=1"
      "-Djdk.graal.CompilerConfiguration=enterprise"
      "-XX:+UseG1GC"
      "-XX:MaxGCPauseMillis=130"
      "-XX:G1NewSizePercent=28"
      "-XX:G1HeapRegionSize=16M"
      "-XX:G1ReservePercent=20"
      "-XX:G1MixedGCCountTarget=3"
      "-XX:InitiatingHeapOccupancyPercent=10"
      "-XX:G1MixedGCLiveThresholdPercent=90"
      "-XX:G1RSetUpdatingPauseTimePercent=0"
      "-XX:SurvivorRatio=32"
      "-XX:MaxTenuringThreshold=1"
      "-XX:G1SATBBufferEnqueueingThresholdPercent=30"
      "-XX:G1ConcMarkStepDurationMillis=5"
      "-XX:+UseTransparentHugePages"
      "-XX:ConcGCThreads=6"
      "--enable-native-access=ALL-UNNAMED"
    ];

    proxy = {
      enable = true;
      openFirewall = true;
      routes =
        let
          servers = config.thm.services.minecraft.servers;
        in
        [
          {
            host = [
              "magic.mc.thehivemind.gay"
              "mc.thehivemind.gay"
            ];
            backend = "localhost:${toString servers.magic.port}";
            fallback = {
              motd = ''
                §cMagic server is offline.
                §eTry necromancy!
              '';
              version.name = "1.20.1 (modded)";
              favicon = ./servers/magic.png;
            };
          }
        ];
    };
  };

}
