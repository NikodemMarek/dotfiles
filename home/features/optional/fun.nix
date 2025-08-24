{pkgs, ...}: {
  home.packages = with pkgs; [
    prismlauncher
    heroic
    steam
    lutris
    wine
    winetricks
  ];
}
