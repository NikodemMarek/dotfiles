{
  settings = {
    name = "nikodem";
    email = "nikodemmarek11@gmail.com";
    eww = {
      shortcuts = [
        [
          ["firefox" ""]
          ["qutebrowser" "󰖟"]
        ]
        [
          ["android-studio" "as"]
          ["beeper --default-frame" "󰵅"]
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

        ./modules/git.nix
        ./modules/tools.nix
        ./modules/firefox.nix
        ./modules/qutebrowser.nix
        ./modules/beets.nix
        ./modules/yt-dlp.nix
      ]
      ++ (
        if settings.device == "laptop"
        then [./modules/battery-notifier.nix]
        else []
      );

    home.packages = with pkgs; [
      beeper
      zathura
      openjdk17
      nodejs
      maven
      android-tools
      android-studio
      hurl
      xh
    ];
  };
}
