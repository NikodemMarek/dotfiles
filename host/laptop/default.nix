{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/btrfs-persistence-swapfile.nix {
      device = "/dev/nvme0n1";
      swap = 15;
    })

    ../features/impermanence.nix
    ../features/hyprland.nix
    ../features/docker.nix
    ../features/dnscrypt-proxy2.nix

    ../features/battery-saver.nix
    ../features/bluetooth.nix
  ];

  networking.hostName = "laptop";

  users.users = {
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ./user_nikodem_ssh_id_ed25519.pub
        ../desktop/user_nikodem_ssh_id_ed25519.pub
        ../LP-043/user_nm1_ssh_id_ed25519.pub
      ];
    };
    fun = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/fun/password".path;
      extraGroups = ["wheel"];
      shell = pkgs.fish;
    };
  };
}
