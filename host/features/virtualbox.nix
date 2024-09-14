{
  virtualisation.virtualbox = {
    host = {
      enable = true;
      enableExtensionPack = true;
    };
    guest = {
      enable = true;
      draganddrop = true;
      clipboard = true;
    };
  };
  users.extraGroups.vboxusers.members = ["nikodem"];
}
