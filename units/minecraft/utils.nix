{ config, lib, ... }:
{
  forEachServer =
    f: lib.concatMapAttrs (name: value: f name value) config.services.minecraft-servers.servers;
}
