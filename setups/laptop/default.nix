{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../host
    ./hardware-configuration.nix

    (import ../../host/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 15;
    })

    ../../secrets

    ../../host/impermanence.nix
    ../../host/hyprland.nix
    ../../host/docker.nix
    ../../host/dnscrypt-proxy2.nix
    ../../host/zerotier.nix

    ../../host/battery-saver.nix
    ../../host/bluetooth.nix
  ];

  networking.hostName = "laptop";

  users.users = {
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "networkmanager" "docker"];
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
      extraGroups = ["wheel" "networkmanager"];
      shell = pkgs.fish;
    };
  };

  services = {
    music = {
      enable = true;
      anysync = true;
      persistent = true;
    };
  };
}
