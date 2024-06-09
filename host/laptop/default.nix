{
  users = [
    {
      username = "nikodem";
      groups = ["wheel" "networkmanager" "docker"];
    }
    {
      username = "fun";
      groups = ["wheel" "networkmanager"];
    }
  ];

  settings = {
    device = "laptop";
    system = "x86_64-linux";
    drive = "/dev/nvme0n1";
    swap = 15;
    configPath = "/dotfiles";
    monitors = [
      # primary display first
      {
        name = "";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        offsetX = 0;
        offsetY = 0;
        transform = 0;
      }
    ];
  };

  module = {
    imports = [
      ./hardware-configuration.nix

      (import ../modules/users.nix (import ./default.nix).users)

      ../modules/impermanence.nix
      ../modules/sops.nix
      ../modules/stylix.nix
      ../modules/networking.nix
      ../modules/openssh.nix
      ../modules/pipewire.nix
      ../modules/greetd.nix
      ../modules/hyprland.nix
      ../modules/docker.nix
      ../modules/dnscrypt-proxy2.nix
      ../modules/tools.nix
      ../modules/music.nix
      ../modules/battery-saver.nix
      ../modules/battery-notifier.nix
      ../modules/bluetooth.nix
      ../modules/graphics.nix
    ];

    networking.hostName = "laptop";

    services = {
      music = {
        enable = true;
        anysync = true;
        persistent = true;
      };
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    };
  };
}
