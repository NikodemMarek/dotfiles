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
    device = "desktop";
    system = "x86_64-linux";
    drive = "/dev/nvme0n1";
    swap = 38;
    configPath = "/dotfiles";
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
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../modules/music.nix

      (import ../modules/users.nix (import ./default.nix).users)
    ];

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
