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
      groups = ["networkmanager" "docker"];
    }
  ];

  settings = {
    device = "desktop";
    monitors = [
      # primary display first
      {
        name = "DP-3";
        width = 2560;
        height = 1440;
        refreshRate = 144;
        offsetX = 0;
        offsetY = 0;
        transform = 0;
      }
      {
        name = "HDMI-A-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        offsetX = 2560;
        offsetY = -240;
        transform = 3;
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
        size = 38 * 1024;
      }
    ];
    boot = {
      kernelParams = ["resume_offset=25928960"];
      resumeDevice = "/dev/disk/by-uuid/fc60a589-f4e6-4f9e-b149-b372221e824b";
    };
    security.protectKernelImage = false;

    boot.extraModulePackages = [
      config.boot.kernelPackages.rtl8821au
    ];

    environment.systemPackages = with pkgs; [
      mesa
      linuxKernel.packages.linux_6_1.rtl8821au
    ];
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
}
