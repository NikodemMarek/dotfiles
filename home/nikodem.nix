{
  lib,
  pkgs,
  settings,
  ...
}: {
  imports =
    [
      ./modules/neovim
      ./modules/hyprland
      ./modules/eww

      ./modules/sops.nix
      ./modules/ssh.nix
      ./modules/beets.nix
      ./modules/yt-dlp.nix
    ]
    ++ (
      if settings.device == "laptop"
      then [./modules/battery-notifier.nix]
      else []
    );

  config = lib.mkIf (settings.device
    == "laptop") {
    services = {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    };

    home.packages = with pkgs; [
      rnote
      beeper
      typst
      zathura
      xh
    ];
  };
}
