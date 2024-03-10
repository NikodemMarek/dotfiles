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
    ...
  }: {
    imports = [
      ./modules/neovim
      ./modules/hyprland
      ./modules/eww

      ./modules/git.nix
      ./modules/tools.nix
      ./modules/firefox.nix
      ./modules/qutebrowser.nix
      ./modules/wired-notify.nix
      ./modules/battery-notifier.nix
    ];

    home.packages = with pkgs; [
      rnote
      beeper
      typst
      zathura
    ];
  };
}
