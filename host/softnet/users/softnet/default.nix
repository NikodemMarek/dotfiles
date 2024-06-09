{pkgs, ...}: {
  imports = [
    ./modules/neovim
    ./modules/hyprland

    ./modules/git.nix
    ./modules/gh.nix
    ./modules/tools.nix
    ./modules/firefox.nix
    ./modules/qutebrowser.nix
    ./modules/wired-notify.nix
    ./modules/battery-notifier.nix
  ];

  settings.monitors = [
    {
      name = "eDP-1";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 0;
      y = 0;
      transform = 0;
    }
    {
      name = "DP-3";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 0;
      y = 0;
      transform = 0;
    }
    {
      name = "DP-4";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 0;
      y = 0;
      transform = 0;
    }
  ];

  home.packages = with pkgs; [
    zathura
    xh
  ];
}
