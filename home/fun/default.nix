{
  pkgs,
  lib,
  host-config,
  config,
  ...
}: {
  imports = [
    ../../host/${host-config.networking.hostName}/kanshi.nix

    ../features/hyprland

    ../features/neovim.nix
    ../features/impermanence.nix
    ../features/beets.nix
    ../features/yt-dlp.nix
  ];

  services =
    {}
    // lib.mkIf (host-config.networking.hostName == "laptop") {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    };

  home = {
    packages = with pkgs; [
      rnote
      beeper
      zathura
      lutris
      prismlauncher
      jdk8
      steam
    ];
    persistence."/persist/${config.home.homeDirectory}".directories = [
      "games"

      ".local/share/PrismLauncher"

      ".local/share/Steam"
    ];
  };
}
