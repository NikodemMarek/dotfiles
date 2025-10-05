{
  lib,
  host-config,
  ...
}: let
  isLaptop = host-config.networking.hostName == "laptop";
  isDesktop = host-config.networking.hostName == "desktop";
in {
  imports = [
    ../features
    ../features/global

    ../../host/${host-config.networking.hostName}/kanshi.nix
    ../../host/${host-config.networking.hostName}/secrets.nix

    ../features/optional/fun.nix
  ];

  sops.defaultSopsFile = ../../host/${host-config.networking.hostName}/secrets.yaml;

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
      userEmail = "62289991+NikodemMarek@users.noreply.github.com";
      userName = "NikodemMarek";
    };
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = ../../host/${host-config.networking.hostName}/user_nikodem_ssh_id_ed25519.pub;
  };
}
