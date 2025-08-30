{ config, lib, ... }:
{
  # Concat map over server names and configs, merging the returned attrsets
  forEachServer =
    f: lib.concatMapAttrs (name: value: f name value) config.services.minecraft-servers.servers;

  # Map over the server names
  forEachServerName =
    f: builtins.map f (builtins.attrNames config.services.minecraft-servers.servers);
}
