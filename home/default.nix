{
  outputs,
  config,
  ...
}: {
  programs.home-manager.enable = true;

  imports =
    [
      ./common
    ]
    ++ (builtins.attrValues outputs.homeManagerModules);

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.05";
  };

  systemd.user.startServices = "sd-switch";
}
