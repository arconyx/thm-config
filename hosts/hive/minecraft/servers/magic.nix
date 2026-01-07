{
  config,
  thm-modpack,
  lib,
  pkgs,
  ...
}:
let
  modpack = thm-modpack.packages.${config.nixpkgs.hostPlatform.system}.default;
  mcVersion = modpack.manifest.versions.minecraft;
  fabricVersion = modpack.manifest.versions.fabric;
  serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
in
{
  thm.services.minecraft.servers.magic = {
    enable = false;
    package = pkgs.fabricServers.${serverVersion}.override {
      loaderVersion = fabricVersion;
      jre_headless = pkgs.graalvmPackages.graalvm-oracle;
    };
    port = 25566;
    settings = {
      gamemode = "survival";
      difficulty = "hard";
      motd = "Operating by necromantic reanimation";
      distance = {
        view = 8;
        simulation = 8;
      };
    };
    symlinks = modpack.modLinks;
    files = {
      "config" = "${modpack}/config";
      "kubejs" = "${modpack}/kubejs";
    };
  };
}
