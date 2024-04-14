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
          ["firefox https://mail.google.com/mail/u/0/#inbox" ""]
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
        ./modules/gh.nix
        ./modules/tools.nix
        ./modules/firefox.nix
        ./modules/qutebrowser.nix
        ./modules/wired-notify.nix
        ./modules/beets.nix
        ./modules/yt-dlp.nix
      ]
      ++ (
        if settings.device == "laptop"
        then [./modules/battery-notifier.nix]
        else []
      );

    home.packages = with pkgs; [
      rnote
      beeper
      typst
      zathura
      xh
    ];
  };
}
