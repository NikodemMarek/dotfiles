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
    wm.monitors = [
      {
        name = "eDP-1";
        width = 1920;
        height = 1080;
        x = 0;
        y = 0;
        transform = 0;
      }
    ];

    services = {
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
  };
}
