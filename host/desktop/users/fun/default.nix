{pkgs, ...}: {
  imports = [
    ../../../../home/modules/neovim
    ../../../../home/modules/hyprland

    ../../../../home/modules/sops.nix
    ../../../../home/modules/ssh.nix
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

  home.packages = with pkgs; [
    rnote
    beeper
    zathura
    lutris
    prismlauncher
    jdk8
    steam
  ];
}
