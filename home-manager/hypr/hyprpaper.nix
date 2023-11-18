{ config, pkgs, lib, workDir, ... }: {
  home.packages = with pkgs; [
    hyprpaper
  ];

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    ipc = off

    preload = ${config.home.homeDirectory}/${config.xdg.configFile."assets/background.png".target}
    wallpaper = , ${config.home.homeDirectory}/${config.xdg.configFile."assets/background.png".target}
  '';
}
