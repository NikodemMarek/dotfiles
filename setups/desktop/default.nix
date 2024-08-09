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
    (import ../../host/disko/btrfs-single-partition.nix {
      device = "/dev/sda";
    })

    ../../host/impermanence.nix
    ../../host/hyprland.nix
    ../../host/docker.nix
    ../../host/dnscrypt-proxy2.nix
    ../../host/zerotier.nix

    ./nextcloud.nix
  ];

  networking.hostName = "desktop";

  users.users = {
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "networkmanager" "docker" "music"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ../desktop/users/nikodem/id_ed25519.pub
        ../laptop/users/nikodem/id_ed25519.pub
        ../LP-043/users/nm1/id_ed25519.pub
      ];
    };
    fun = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/fun/password".path;
      extraGroups = ["wheel" "networkmanager" "music"];
      shell = pkgs.fish;
    };
  };

  boot.extraModulePackages = [config.boot.kernelPackages.rtl8821au];
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
