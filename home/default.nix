{config, ...}: {
  programs.home-manager.enable = true;

  imports = [
    ./modules/common
  ];

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "23.11";
  };

  systemd.user.startServices = "sd-switch";
}
