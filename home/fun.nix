{
  pkgs,
  settings,
  ...
}: {
  imports =
    [
      ./modules/neovim
      ./modules/hyprland

      ./modules/sops.nix
      ./modules/ssh.nix
    ]
    ++ (
      if settings.device == "laptop"
      then [./modules/battery-notifier.nix]
      else []
    );

  wm.monitors = [
    {
      name = "eDP-1";
      width = 1920;
      height = 1080;
      x = 0;
      y = 0;
      transform = 0;
    }
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
