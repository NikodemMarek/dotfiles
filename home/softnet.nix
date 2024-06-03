{
  settings = {
    name = "nm1";
    email = "nikodem.marek@softnet.com.pl";
    eww = {
      shortcuts = [
        [
          ["firefox" ""]
          ["qutebrowser" "󰖟"]
        ]
      ];
    };
  };

  module = {pkgs, ...}: {
    imports = [
      ./modules/neovim
      ./modules/hyprland
      ./modules/eww

      ./modules/git.nix
      ./modules/gh.nix
      ./modules/tools.nix
      ./modules/firefox.nix
      ./modules/qutebrowser.nix
      ./modules/wired-notify.nix
      ./modules/battery-notifier.nix
    ];

    home.packages = with pkgs; [
      zathura
      xh
    ];
  };
}
