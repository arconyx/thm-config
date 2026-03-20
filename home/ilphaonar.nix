{ pkgs, ... }:
{
  arcworks.users.ilphaonar = {
    enable = true;
    shell = pkgs.fish;
  };

  home-manager.users.ilphaonar = { };
}
