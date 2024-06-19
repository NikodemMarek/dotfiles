{pkgs, ...}: {
  imports = [
    ../../../../home
    ../../../../home/neovim
    ../../../../home/hyprland

    ../../../../home/impermanence.nix
    ../../../../home/ssh.nix
    ../../../../home/beets.nix
    ../../../../home/yt-dlp.nix
  ];

  home.username = "nikodem";

  settings = {
    monitors = [
      {
        name = "eDP-1";
        width = 1920;
        height = 1080;
        x = 0;
        y = 0;
        transform = 0;
      }
    ];
  };

  services = {
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT1/capacity";
      statusPath = "/sys/class/power_supply/BAT1/status";
    };
  };

  programs = {
    git = {
      userEmail = "nikodemmarek11@gmail.com";
      userName = "NikodemMarek";
    };
  };

  home.packages = with pkgs; [
    rnote
    beeper
    typst
    zathura
    xh
  ];
}
