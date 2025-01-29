{
  pkgs,
  lib,
  host-config,
  ...
}: {
  imports = [
    ../../host/${host-config.networking.hostName}/kanshi.nix

    ../features/hyprland

    ../features/neovim.nix
    ../features/ssh.nix
    ../features/docker.nix
    ../features/beets.nix
    ../features/yt-dlp.nix
    ../features/obsidian.nix
    ../features/fabric-ai.nix
    ../features/ollama.nix
  ];

  services =
    {
      eww = {
        enable = true;
        monitor =
          if host-config.networking.hostName == "laptop"
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
              battery = "true";
            };
          };
          clock.grid = [4 2 8 5];
          music.grid = [0 5 4 2];
          volume.grid = [4 0 4 2];
        };
      };
    }
    // lib.optionalAttrs (host-config.networking.hostName == "laptop") {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    };

  programs = {
    git = {
      userEmail = "nikodemmarek11@gmail.com";
      userName = "NikodemMarek";
    };
  };

  home.packages = with pkgs; [
    rnote
    beeper
    typst
    zathura
    xh
  ];

  persist = {
    generated.directories = [
      ".config/JetBrains"

      ".local/share/JetBrains"
    ];
    data.directories = lib.optional host-config.virtualisation.virtualbox.host.enable "vms";
  };
}
