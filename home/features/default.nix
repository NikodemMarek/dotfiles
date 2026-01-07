{
  outputs,
  config,
  ...
}: {
  imports =
    []
    ++ (builtins.attrValues outputs.homeManagerModules);

  programs.home-manager.enable = true;

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.05";
  };

  systemd.user.startServices = "sd-switch";
}
