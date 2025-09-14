{
  imports = [
    ./ct-base.nix

    ./proxy.nix
    ./jellyfin.nix
    ./monitoring.nix
  ];

  users.users.root = {
    password = "1234";
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
    nameservers = ["1.1.1.1"];
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
