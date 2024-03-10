{
  settings = {
    eww = {
      shortcuts = [
        [
          ["firefox" ""]
          ["qutebrowser" "󰖟"]
          ["steam" "st"]
        ]
        [
          ["lutris" "lt"]
          ["beeper --default-frame" "󰵅"]
          ["prismlauncher" "mc"]
        ]
      ];
    };
  };

  module = {
    inputs,
    outputs,
    lib,
    config,
    pkgs,
    settings,
    ...
  }: {
    imports =
      [
        ./modules/neovim
        ./modules/hyprland
        ./modules/eww

        ./modules/tools.nix
        ./modules/firefox.nix
        ./modules/qutebrowser.nix
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
    ];
  };
}
