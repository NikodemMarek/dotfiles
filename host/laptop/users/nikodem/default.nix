{pkgs, ...}: {
  imports = [
    ../../../../home
    ../../../../home/modules/neovim
    ../../../../home/modules/hyprland

    ../../../../home/modules/impermanence.nix
    ../../../../home/modules/sops.nix
    ../../../../home/modules/ssh.nix
    ../../../../home/modules/beets.nix
    ../../../../home/modules/yt-dlp.nix
    ../../../../home/modules/battery-notifier.nix
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
