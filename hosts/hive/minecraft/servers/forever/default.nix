{
  pkgs,
  ...
}:
let
  modpack = pkgs.fetchPackwizModpack {
    src = ./packwiz;
    packHash = "sha256-QODiJYgwFGI++5j0f7n+2hYNAUtQJoORQWXP95Ku4hY=";
  };
in
{
  thm.services.minecraft.servers.forever = {
    enable = true;
    package = pkgs.fabricServers.fabric-1_21_11.override {
      jre_headless = pkgs.graalvmPackages.graalvm-oracle;
    };
    port = 25567;
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
}
