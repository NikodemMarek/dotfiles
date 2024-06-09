{
  config,
  pkgs,
  ...
}: {
  imports = [
    (import ../modules/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })

    ../modules/disko
    ../modules/impermanence.nix
    ../modules/sops.nix
    ../modules/hyprland.nix
    ../modules/docker.nix
    ../modules/dnscrypt-proxy2.nix
    ../modules/music.nix
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
