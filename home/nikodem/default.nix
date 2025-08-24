{
  pkgs,
  lib,
  host-config,
  ...
}: let
  isLaptop = host-config.networking.hostName == "laptop";
  isDesktop = host-config.networking.hostName == "desktop";
  isLP043 = host-config.networking.hostName == "LP-043";
in {
  imports =
    [
      ../features/hyprland
      ../features/clipboard-sync

      ../features/neovim.nix
      ../features/ssh.nix
      ../features/docker.nix
      ../features/beets.nix
      ../features/yt-dlp.nix
      ../features/obsidian.nix
      ../features/fabric-ai.nix
      ../features/ollama.nix
      ../features/zen-browser.nix
      ../features/coding.nix
    ]
    ++ (lib.optional (isLaptop || isDesktop) ../../host/${host-config.networking.hostName}/kanshi.nix);

  services =
    {
      eww = {
        enable = true;
        monitor =
          if isLaptop || isLP043
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
                if isLaptop || isLP043
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
    // lib.optionalAttrs (isLaptop
      || isLP043) {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    };

  programs = {
    git = {
      userEmail = "62289991+NikodemMarek@users.noreply.github.com";
      userName = "NikodemMarek";
    };
  };

  home.packages = with pkgs; [
    rnote
    beeper
    typst
    zathura
    xh
    postman
  ];
}
