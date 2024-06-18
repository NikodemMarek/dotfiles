{pkgs, ...}: {
  imports = [
    ../../../../home
    ../../../../home/modules/neovim
    ../../../../home/modules/hyprland

    ../../../../home/modules/ssh.nix
  ];

  home.username = "fun";

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
