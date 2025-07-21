{pkgs, ...}: {
  home.packages = with pkgs; [
    prismlauncher
    heroic
    steam
    lutris
    jdk8
    wine
    winetricks
  ];
}
