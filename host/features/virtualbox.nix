{
  boot.kernelModules = ["kvm-intel" "kvm-amb"];
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
}
