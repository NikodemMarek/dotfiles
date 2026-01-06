# set `services.syncthing.user = "<user>";` in host config
{config, ...}: let
  user = config.services.syncthing.user;
  userHome = config.users.users.${user}.home;
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
    group = "users";
    dataDir = "${userHome}/.local/share/syncthing";
    configDir = "${userHome}/.config/syncthing";
  };
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  persist.generated.directories = [
    {
      inherit (config.services.syncthing) user group;
      directory = "/home/${user}/.local/share/syncthing";
      mode = "770";
    }
    {
      inherit (config.services.syncthing) user group;
      directory = "/home/${user}/.config/syncthing";
      mode = "770";
    }
  ];
}
