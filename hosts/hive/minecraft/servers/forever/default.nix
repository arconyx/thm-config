{
  pkgs,
  ...
}:
let
  modpack = pkgs.fetchPackwizModpack {
    src = ./packwiz;
    packHash = "sha256-dNRii1/9Di+iwvfCaz1Zlt0CGAnaFiD9ttfo6LW+cBk=";
  };
in
{
  thm.services.minecraft.servers.forever = {
    enable = true;
    package = pkgs.fabricServers.fabric-1_21_11.override {
      jre_headless = pkgs.graalvmPackages.graalvm-oracle;
    };
    port = 25567;
    alwaysOn = true;
    settings = {
      gamemode = "survival";
      difficulty = "hard";
      motd = "The world is born anew";
      distance = {
        view = 12;
        simulation = 8;
      };
      extraConfig = {
        region-file-compression = "lz4";
        level-seed = "thm unlimited";
      };
    };
    symlinks = {
      mods = "${modpack}/mods";
    };
    # nix-minecraft has a collectFilesAt function as a symlink helper
    # might be worth using if this attrset gets more complex
    files = {
      config = "${modpack}/config";
      resources = "${modpack}/resources";
    };
    backup = false;
  };

  # for Spark
  systemd.services.minecraft-server-forever.serviceConfig.CapabilityBoundingSet = [ "CAP_PERFMON" ];
}
