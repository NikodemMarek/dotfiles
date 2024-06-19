{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../../../home
    ../../../../home/modules/neovim
    ../../../../home/modules/hyprland

    ../../../../home/modules/ssh.nix
  ];

  settings.monitors = [
    {
      name = "eDP-1";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 0;
      y = 0;
      transform = 0;
    }
    {
      name = "DP-3";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 0;
      y = -1080;
      transform = 0;
    }
    {
      name = "DP-4";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 1920;
      y = -1260;
      transform = 3;
    }
  ];

  services = {
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT0/capacity";
      statusPath = "/sys/class/power_supply/BAT0/status";
    };

    openfortivpn = {
      enable = true;
      host = builtins.readFile config.sops.secrets."openfortivpn/host".path;
      port = builtins.readFile config.sops.secrets."openfortivpn/port".path;
      username = builtins.readFile config.sops.secrets."openfortivpn/username".path;
      password = builtins.readFile config.sops.secrets."openfortivpn/password".path;
      realm = builtins.readFile config.sops.secrets."openfortivpn/realm".path;
      trusted-cert = builtins.readFile config.sops.secrets."openfortivpn/trusted_cert".path;
      user-cert = config.sops.secrets."openfortivpn/user_cert".path;
      user-key = config.sops.secrets."openfortivpn/user_key".path;
    };
  };

  programs = {
    git = {
      userEmail = "nikodem.marek@softnet.com.pl";
      userName = "nm1";
    };
  };

  home.packages = with pkgs; [
    rocketchat-desktop
    zathura
    kooha
    obs-studio
    xh
    pnpm
    jdk11
    sshpass
    maven
    remmina
    nodejs_22
    google-chrome
    android-studio
    jetbrains.idea-ultimate
    jetbrains.pycharm-community
    jetbrains.datagrip
  ];
}
