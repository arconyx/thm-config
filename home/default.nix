{
  lib,
  config,
  ...
}:

{
  config.home-manager.users.arc = lib.mkIf config.arcworks.users.arc.enable {
    programs.git = {
      userName = "ArcOnyx";
      userEmail = "11323309+arconyx@users.noreply.github.com";
    };
  };
}
