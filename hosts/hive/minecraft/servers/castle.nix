# The original THM server, revived for the 10th anniversary
{
  pkgs,
  ...
}:
{
  thm.services.minecraft.servers.castle = {
    enable = true;
    package = pkgs.fabricServers.fabric-1_21_11.override {
      jre_headless = pkgs.openjdk25_headless;
    };
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
      "mods/fabric-api-0.141.3.jar" = pkgs.fetchurl {
        url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/i5tSkVBH/fabric-api-0.141.3%2B1.21.11.jar";
        hash = "sha256-hsRTqGE5Zi53VpfQOwynhn9Uc3SGjAyz49wG+Y2/7vU=";
      };
      "mods/lithium-fabric-0.21.3.jar" = pkgs.fetchurl {
        url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/qvNsoO3l/lithium-fabric-0.21.3%2Bmc1.21.11.jar";
        hash = "sha256-hsG97K3MhVgBwvEMnlKJTSHJPjxSl8qDJwdN3RIeXFo=";
      };
    };
    files = {
      "config/amcdb.properties" = ./forever/packwiz/config/amcdb.properties;
    };
  };
}
