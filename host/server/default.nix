{
  inputs,
  lib,
  modulesPath,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.11";

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  boot.loader = {
    grub = {
      enable = lib.mkForce false;
      devices = ["nodev"];
    };
    systemd-boot.enable = lib.mkForce false;
  };

  imports = [
    inputs.sops-nix.nixosModules.sops

    "${toString modulesPath}/virtualisation/proxmox-lxc.nix"

    ./jellyfin.nix
    ./monitoring.nix
  ];

  users.users.root = {
    openssh.authorizedKeys.keyFiles = [
      ../laptop/user_nikodem_ssh_id_ed25519.pub
      ../../home/nm1/user_nm1_ssh_id_ed25519.pub
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  networking = {
    hostName = "server";
    useNetworkd = true;
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "10.0.0.100";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "10.0.0.1";
      interface = "eth0";
    };
    firewall.enable = true;
  };

  programs = {
    neovim.enable = true;
    git.enable = true;
  };

  services = {
    zerotierone = {
      enable = true;
      joinNetworks = [
        "6ab565387a704125"
      ];
    };
  };
}
