{
  pkgs,
  ...
}:
let
  rev = "2ad25f79a6a8464fe99f0c17d27bc7193b37595d";
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/arconyx/thm-modpack/raw/${rev}/pack.toml";
    packHash = "sha256-Ke3X9UJ0w7GuM66zwn9+FQJmsnwobvmJSkhSPLX/D7M=";
  };
in
{
  thm.services.minecraft.servers.forever-test = {
    enable = true;
    package = pkgs.fabricServers.fabric-1_21_11.override {
      jre_headless = pkgs.graalvmPackages.graalvm-oracle;
    };
    port = 25567;
    settings = {
      gamemode = "creative";
      difficulty = "hard";
      motd = "The world is a house of sand, soon to crumble and fall";
      distance = {
        view = 12;
        simulation = 8;
      };
      extraConfig = {
        region-file-compression = "lz4";
      };
    };
    symlinks = {
      mods = "${modpack}/mods";
    };
    files = {
      "config" = "${modpack}/config";
    };
  };
}
