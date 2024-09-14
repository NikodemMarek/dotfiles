{
  outputs,
  host-config,
  config,
  ...
}: {
  imports =
    [
      ./global
      ../../host/${host-config.networking.hostName}/secrets.nix
    ]
    ++ (builtins.attrValues outputs.homeManagerModules);

  programs.home-manager.enable = true;

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.05";
  };

  systemd.user.startServices = "sd-switch";
}
