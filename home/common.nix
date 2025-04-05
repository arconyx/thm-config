{ ... }:

{
  home = {

    # This value determines the home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update home Manager without changing this value. See
    # the home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "24.11";
  };

  programs = {
    firefox.enable = true;
    home-manager.enable = true; # Let home Manager install and manage itself.
    bash.enable = true;
  };
}
