{
  boot.kernelModules = ["kvm-intel" "kvm-amb"];
  virtualisation.virtualbox = {
    host = {
      enable = true;
      enableExtensionPack = true;
    };
    guest = {
      enable = true;
      dragAndDrop = true;
      clipboard = true;
    };
  };

  users.extraGroups.vboxusers.members = ["nikodem"];
}
