{
  lib,
  host-config,
  ...
}: let
  isLaptop = host-config.networking.hostName == "laptop";
  isDesktop = host-config.networking.hostName == "desktop";
in {
  imports = [
    ../../host/${host-config.networking.hostName}/kanshi.nix

    ../features/optional/fun.nix
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
      };
    }
    // lib.optionalAttrs isLaptop {
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
}
