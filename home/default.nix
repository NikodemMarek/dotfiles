{config, ...}: {
  programs.home-manager.enable = true;

  imports = [
    ./modules/common
  ];

  home = {
    inherit (config.settings) username;
    homeDirectory = "/home/${config.settings.username}";
  };

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.11";
}
