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
    ];

    # boot = {
    #   kernelParams = ["resume_offset=25442627"];
    #   resumeDevice = "/dev/disk/by-uuid/b537105a-8de8-4724-807c-039e5b23f3bb";
    # };

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
