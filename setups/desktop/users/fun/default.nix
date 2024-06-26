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
