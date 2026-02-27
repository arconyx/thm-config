{ pkgs, ... }:
{
  arcworks.users.ilphaonar = {
    enable = true;
    shell = pkgs.fish;
    hide = true;
  };

  home-manager.users.ilphaonar = { };
}
