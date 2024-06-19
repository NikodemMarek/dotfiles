{
  config,
  pkgs,
  ...
}: {
  imports = [
    (import ../../host/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })

    ../../host/impermanence.nix
    ../../host/sops.nix
    ../../host/hyprland.nix
    ../../host/docker.nix
    ../../host/dnscrypt-proxy2.nix
  ];

  networking.hostName = "desktop";

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
}
