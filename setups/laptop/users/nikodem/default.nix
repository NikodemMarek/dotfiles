{pkgs, ...}: {
  imports = [
    ../../../../home
    ../../../../home/neovim
    ../../../../home/hyprland

    ../../../../home/impermanence.nix
    ../../../../home/ssh.nix
    ../../../../home/docker.nix
    ../../../../home/beets.nix
    ../../../../home/yt-dlp.nix
    ../../../../home/obsidian.nix
  ];

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
