{
  pkgs,
  lib,
  config,
  ...
}: {
  options.node-image = {
    number = lib.mkOption {
      type = lib.types.int;
      description = "The node number in the cluster.";
    };
  };

  config = let
    cfg = config.node-image;

    isMaster = cfg.number == 0;
    masterNodeIP = "192.168.74.2";
  in {
    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion = "25.11";

    users.users = {
      root = {
        hashedPassword = "!";
        openssh.authorizedKeys.keyFiles = [
          ../../laptop/user_nikodem_ssh_id_ed25519.pub
        ];
      };
    };

    networking = {
      interfaces.eth0 = {
        ipv4.addresses = [
          {
            address = "192.168.74.${toString (cfg.number + 2)}";
            prefixLength = 24;
          }
        ];
      };
      defaultGateway = {
        address = "192.168.74.1";
        interface = "eth0";
      };
    };

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    networking.extraHosts = "${masterNodeIP} api.kube";

    services.kubernetes = {
      roles = ["node"] ++ lib.optional isMaster "master";
      masterAddress = "api.kube";
      apiserverAddress = "https://api.kube:6443";
      easyCerts = true;
      apiserver = lib.mkIf isMaster {
        securePort = 6443;
        advertiseAddress = masterNodeIP;
      };
      # addons.dns.enable = true;
    };

    environment.systemPackages = [
      pkgs.kubernetes
      pkgs.kubectl
      pkgs.fluxcd
      pkgs.kubernetes-helm
    ];
  };
}
