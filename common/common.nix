{
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./audio.nix
    ./boot.nix
    ./display.nix
    ./environment.nix
    ./locale.nix
    ./networking.nix
    ./users.nix
  ];

  # label generations by git commit hash
  system.configurationRevision =
    let
      self = inputs.self;
    in
    self.shortRev or self.dirtyShortRev or self.lastModified or "unknown";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # Limit the number of generations to keep
  boot.loader.systemd-boot.configurationLimit = 10;

  # Perform garbage collection monthly to maintain low disk usage
  nix.gc = {
    automatic = true;
    dates = "monthly";
    options = "--delete-older-than 30d";
  };
}
