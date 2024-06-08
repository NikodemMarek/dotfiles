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

  module = {pkgs, ...}: {
    imports = [
      ../modules/music.nix
      ../modules/impermanence.nix

      (import ../modules/users.nix (import ./default.nix).users)
    ];

    environment.systemPackages = with pkgs; [
      mesa
    ];

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    hardware.opengl.driSupport32Bit = true;

    services.thermald.enable = true;
    services.auto-cpufreq.enable = true;
  };
}
