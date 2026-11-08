{
  pkgs,
  ...
}:
{
  # Use Lix
  nix.package = pkgs.lixPackageSets.latest.lix;

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
      "coerce-integers"
    ];
    use-xdg-base-directories = true;
  };

  # Perform garbage collection to maintain low disk usage
  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
    options = "--delete-older-than 14d";
  };
}
