{
  host-config,
  pkgs,
  ...
}: {
  imports = [
    ../features
    ../features/global

    ../../host/${host-config.networking.hostName}/kanshi.nix
    ../../host/${host-config.networking.hostName}/secrets.nix

    ../features/optional/fun.nix
  ];

  home.packages = [
    pkgs.gemini-cli
    pkgs.nmap
    pkgs.tcpdump
    pkgs.lsof
  ];

  sops.defaultSopsFile = ../../host/${host-config.networking.hostName}/secrets.yaml;

  services = {
    eww = {
      enable = true;
      monitor = {
        width = 1920;
        height = 1080;
      };
    };
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT1/capacity";
      statusPath = "/sys/class/power_supply/BAT1/status";
    };
  };

  programs = {
    git.settings.user = {
      email = "62289991+NikodemMarek@users.noreply.github.com";
      name = "NikodemMarek";
    };
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = ../../host/${host-config.networking.hostName}/user_nikodem_ssh_id_ed25519.pub;
  };
}
