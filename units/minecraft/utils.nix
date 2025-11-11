{ config, lib, ... }:
{
  # Concat map over server names and configs, merging the returned attrsets
  # Only includes enabled servers
  forEachServer =
    f:
    lib.concatMapAttrs (name: value: f name value) (
      lib.filterAttrs (name: cfg: cfg.enable) config.services.minecraft-servers.servers
    );

  # Map over the server names
  # Only includes enabled servers
  forEachServerName =
    f:
    builtins.map f (
      builtins.attrNames (
        lib.filterAttrs (name: cfg: cfg.enable) config.services.minecraft-servers.servers
      )
    );
}
