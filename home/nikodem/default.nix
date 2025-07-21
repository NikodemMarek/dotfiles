{
  lib,
  host-config,
  ...
}: let
  isLaptop = host-config.networking.hostName == "laptop";
  isDesktop = host-config.networking.hostName == "desktop";
  isLP043 = host-config.networking.hostName == "LP-043";
in {
  imports = lib.optionals (isLaptop || isDesktop) [
    ../../host/${host-config.networking.hostName}/kanshi.nix

    ../features/optional/fun.nix
  ];

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
      };
    }
    // lib.optionalAttrs isLaptop {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    }
    // lib.optionalAttrs isLP043 {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT0/capacity";
        statusPath = "/sys/class/power_supply/BAT0/status";
      };
    };

  programs = {
    git =
      if isLaptop
      then {
        userEmail = "nikodemmarek11@gmail.com";
        userName = "NikodemMarek";
      }
      else {
        userEmail = "nikodem.marek@softnet.com.pl";
        userName = "Nikodem Marek";
      };
  };
}
