{
  pkgs,
  lib,
  host-config,
  ...
}: let
  isLaptop = host-config.networking.hostName == "laptop";
in {
  imports = [
    ../../host/${host-config.networking.hostName}/kanshi.nix

    ../features/hyprland

    ../features/neovim.nix
    ../features/beets.nix
    ../features/yt-dlp.nix
    ../features/zen-browser.nix
  ];

  services =
    {
      eww = {
        enable = true;
        monitor =
          if isLaptop
          then {
            width = 1920;
            height = 1080;
          }
          else {
            width = 2560;
            height = 1440;
          };
        windows = {
          powermenu.grid = [12 0 4 2];
          system = {
            grid = [0 2 4 3];
            args = {
              battery =
                if isLaptop
                then "true"
                else "false";
            };
          };
          clock.grid = [4 2 8 5];
          music.grid = [0 5 4 2];
          volume.grid = [4 0 4 2];
        };
      };
    }
    // lib.optionalAttrs isLaptop {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    };

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
