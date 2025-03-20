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
    ../features/beets.nix
    ../features/yt-dlp.nix
    ../features/zen-browser.nix
  ];

  services =
    {}
    // lib.optionalAttrs (host-config.networking.hostName == "laptop") {
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
