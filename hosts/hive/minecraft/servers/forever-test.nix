{
  pkgs,
  ...
}:
let
  rev = "3cfa9bc9efa195f7009442b0a330a69ec5b85898";
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/arconyx/thm-modpack/raw/${rev}/pack.toml";
    packHash = "sha256-9S2UKCVWEer2iqcfvieWuAqGMMvUmfE+FDkd7Q0qiC8=";
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
    backup = false;
  };
}
