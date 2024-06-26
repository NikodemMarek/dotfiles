{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../host
    ./hardware-configuration.nix

    (import ../../host/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 15;
    })

    ../../host/impermanence.nix
    ../../host/hyprland.nix
    ../../host/docker.nix
    ../../host/dnscrypt-proxy2.nix

    ../../host/battery-saver.nix
    ../../host/bluetooth.nix
  ];

  networking.hostName = "laptop";

  users.users = {
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "networkmanager" "docker"];
      shell = pkgs.fish;
    };
    fun = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/fun/password".path;
      extraGroups = ["wheel" "networkmanager"];
      shell = pkgs.fish;
    };
  };

  services = {
    music = {
      enable = true;
      anysync = true;
      persistent = true;
    };
  };

  settings = {
    monitors = [
      {
        name = "eDP-1";
        width = 1920;
        height = 1080;
        x = 0;
        y = 0;
        transform = 0;
      }
    ];
  };
}
