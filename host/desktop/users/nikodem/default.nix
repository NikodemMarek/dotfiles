{pkgs, ...}: {
  imports = [
    ../../../../home/modules/neovim
    ../../../../home/modules/hyprland

    ../../../../home/modules/sops.nix
    ../../../../home/modules/ssh.nix
    ../../../../home/modules/beets.nix
    ../../../../home/modules/yt-dlp.nix
  ];

  settings = {
    monitors = [
      {
        name = "DP-3";
        width = 2560;
        height = 1440;
        refreshRate = 144;
        x = 0;
        y = 0;
        transform = 0;
      }
      {
        name = "HDMI-A-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 2560;
        y = -240;
        transform = 3;
      }
    ];
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
