# The original THM server, revived for the 10th anniversary
{
  pkgs,
  ...
}:
{
  thm.services.minecraft.servers.castle = {
    enable = false;
    package = pkgs.fabricServers.fabric-1_21_11;
    port = 25568;
    settings = {
      gamemode = "creative";
      difficulty = "normal";
      motd = "Undead. Changes may be wiped.";
      distance = {
        view = 8;
        simulation = 5;
      };
      extraConfig = {
        force-gamemode = true;
      };
    };
    backup = false;
    symlinks = {
      "mods/amcdb-1.3.0.jar" = pkgs.fetchurl {
        url = "https://cdn.modrinth.com/data/8X31FLYC/versions/AF4dKwqr/amcdb-1.3.0.jar";
        hash = "sha512-0GsVprBJs1L5c+6xKMkkafZ2AxIwj9C0HbsR5/v5QIwhY7jXEoJoOyiau1SZjkHUFGrpvAwYOWFhUS4984N4fA==";
      };
    };
    files = {
      "config/amcdb.properties" = ./forever/packwiz/config/amcdb.properties;
    };
    jvmOpts = [
      "-Xms8G"
      "-Xmx8G"
      "-XX:+UnlockExperimentalVMOptions"
      "-XX:+UnlockDiagnosticVMOptions"
      "-XX:+AlwaysActAsServerClassMachine"
      "-XX:+AlwaysPreTouch"
      "-XX:+DisableExplicitGC"
      "-XX:+UseNUMA"
      "-XX:NmethodSweepActivity=1"
      "-XX:ReservedCodeCacheSize=400M"
      "-XX:NonNMethodCodeHeapSize=12M"
      "-XX:ProfiledCodeHeapSize=194M"
      "-XX:NonProfiledCodeHeapSize=194M"
      "-XX:-DontCompileHugeMethods"
      "-XX:MaxNodeLimit=240000"
      "-XX:NodeLimitFudgeFactor=8000"
      "-XX:+UseVectorCmov"
      "-XX:+PerfDisableSharedMem"
      "-XX:+UseFastUnorderedTimeStamps"
      "-XX:+UseCriticalJavaThreadPriority"
      "-XX:ThreadPriorityPolicy=1"
      "-XX:AllocatePrefetchStyle=3"
      "-XX:+UseG1GC"
      "-XX:MaxGCPauseMillis=130"
      "-XX:+UnlockExperimentalVMOptions"
      "-XX:+DisableExplicitGC"
      "-XX:+AlwaysPreTouch"
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
      "-XX:G1ConcRSHotCardLimit=16"
      "-XX:G1ConcRefinementServiceIntervalMillis=150"
    ];
  };
}
