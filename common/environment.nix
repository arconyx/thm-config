{ pkgs, ... }:

{
  imports = [
    ./../units/backup.nix
  ];

  # services
  services.fwupd.enable = true;

  # programs
  programs = {
    bat.enable = true;
    git.enable = true; # configured in home/common.nix
    nix-ld.enable = true;

    # default neovim config for editing as root
    # overriden by home manager
    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      configure = {
        customRC = ''
            set number
          	set shiftwidth=4 smarttab
          	set tabstop=7 softtabstop=0
        '';
      };
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # archives
    zip
    xz
    unzip
    _7zz

    # utils
    which
    htop
  ];
}
