{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../host
    ./hardware-configuration.nix

    (import ../../host/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })

    ../../host/impermanence.nix
    ../../host/hyprland.nix
    ../../host/docker.nix
    ../../host/dnscrypt-proxy2.nix
  ];

  networking.hostName = "desktop";

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

  boot.extraModulePackages = [
    config.boot.kernelPackages.rtl8821au
  ];
  environment.systemPackages = with pkgs; [
    linuxKernel.packages.linux_6_1.rtl8821au
  ];

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
        name = "DP-3";
        width = 2560;
        height = 1440;
        refreshRate = 144;
        x = 0;
        y = 0;
        transform = 0;
      }
      {
        name = "HDMI-A-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 2560;
        y = -240;
        transform = 3;
      }
    ];
  };
}
