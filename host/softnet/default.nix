{
  users = [
    {
      username = "softnet";
      groups = ["wheel" "networkmanager" "docker"];
    }
  ];

  settings = {
    device = "softnet";
    system = "x86_64-linux";
    drive = "/dev/nvme0n1";
    swap = 38;
    configPath = "/dotfiles";
    monitors = [
      # primary display first
      {
        name = "eDP-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        offsetX = 0;
        offsetY = 0;
        transform = 0;
      }
      {
        name = "DP-3";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        offsetX = 0;
        offsetY = 0;
        transform = 0;
      }
      {
        name = "DP-4";
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
      ../modules/impermanence.nix
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
