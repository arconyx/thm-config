{
  pkgs,
  ...
}:
let
  modpack = pkgs.fetchPackwizModpack {
    src = ./packwiz;
    packHash = "sha256-6FsYOlkrrkJME0N3HFbxMcN21QfMA7RXHHvJfsTIGWM=";
  };
in
{
  thm.services.minecraft.servers.forever = {
    enable = true;
    package = pkgs.fabricServers.fabric-1_21_11.override {
      jre_headless = pkgs.graalvmPackages.graalvm-oracle;
    };
    port = 25567;
    alwaysOn = false;
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
      # reference files instead of dir
      # because squaremap writes map data to the squaremap dir
      # and we don't want to overwrite it
      "squaremap/config.yml" = "${modpack}/squaremap/config.yml";
      "squaremap/advanced.yml" = "${modpack}/squaremap/advanced.yml";
    };
  };

  # for Spark
  systemd.services.minecraft-server-forever.serviceConfig.CapabilityBoundingSet = [ "CAP_PERFMON" ];
}
