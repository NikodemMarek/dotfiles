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
