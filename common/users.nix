{ ... }:

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    arc = {
      isNormalUser = true;
      description = "ArcOnyx";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      uid = 1000;
    };
    fishynz = {
      isNormalUser = true;
      description = "fishynz";
      extraGroups = [
        "networkmanager"
      ];
    };
  };
}
