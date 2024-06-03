{
  outputs,
  config,
  pkgs,
  hostname,
  users,
  ...
}: let
  mkSystemUser = {
    username,
    groups,
    ...
  }: {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."hosts/${hostname}/users/${username}/password".path;
    extraGroups = groups;
    shell = pkgs.fish;
  };
in {
  imports = [
    ./${hostname}/hardware-configuration.nix

    ./modules/sops.nix
    ./modules/stylix.nix
    ./modules/networking.nix
    ./modules/dnscrypt-proxy2.nix
    ./modules/docker.nix
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 30;
    timeout = 0;
  };

  security.protectKernelImage = false;

  programs = {
    fish.enable = true;
    hyprland.enable = true;
    git.enable = true;
    nix-ld.dev.enable = true;
    ssh.startAgent = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    direnv.enable = true;
  };
  environment.variables.EDITOR = "nvim";

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd ${pkgs.hyprland}/bin/Hyprland -r -t";
        };
      };
    };
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = true;
      };

      hostKeys = [
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  users.users = builtins.listToAttrs (builtins.map
    (user: {
      name = user.username;
      value = mkSystemUser {
        inherit (user) username groups;
      };
    })
    users);

  system.stateVersion = "23.11";
}
