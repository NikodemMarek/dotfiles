{pkgs, ...}: {
  imports = [
    ../../../../home/modules/neovim
    ../../../../home/modules/hyprland

    ../../../../home/modules/git.nix
    ../../../../home/modules/gh.nix
    ../../../../home/modules/tools.nix
    ../../../../home/modules/firefox.nix
    ../../../../home/modules/qutebrowser.nix
    ../../../../home/modules/wired-notify.nix
    ../../../../home/modules/battery-notifier.nix
    ../../../../home/modules/openfortivpn.nix
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
      y = 0;
      transform = 0;
    }
    {
      name = "DP-4";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 0;
      y = 0;
      transform = 0;
    }
  ];

  services = {
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT1/capacity";
      statusPath = "/sys/class/power_supply/BAT1/status";
    };
    openfortivpn = {
      enable = true;
      server = "80.82.19.178";
      username = "nm1";
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
    xh

    android-studio
    jetbrains.idea-community
    jetbrains.pycharm-community
  ];
}
