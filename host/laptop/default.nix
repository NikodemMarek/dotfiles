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
    {
      username = "rustchain";
      groups = ["networkmanager"];
    }
  ];

  settings = {
    device = "laptop";
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
    inputs,
    outputs,
    lib,
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../modules/music.nix
    ];

    fileSystems = {
      "/".options = ["compress=lzo"];
      "/home".options = ["compress=lzo"];
      "/nix".options = ["compress=lzo" "noatime"];
    };

    swapDevices = [
      {
        device = "/swapfile";
        size = 15 * 1024;
      }
    ];
    boot = {
      kernelParams = ["resume_offset=25442627"];
      resumeDevice = "/dev/disk/by-uuid/b537105a-8de8-4724-807c-039e5b23f3bb";
    };

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
