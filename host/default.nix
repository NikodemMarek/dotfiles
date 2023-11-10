{ inputs, outputs, lib, config, pkgs, hostname, users, ... }:
let
  mkSystemUser = { username, groups, ... }: {
      initialPassword = username;
      isNormalUser = true;
      extraGroups = groups;
      shell = pkgs.fish;
    };
in {
  imports = [
    ./${hostname}/hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 30;
  boot.loader.timeout = 0;

  networking.hostName = hostname;
  networking.firewall.enable = false;
  networking.networkmanager.enable = true;

  # FIXME: Do something to abstract this.
  fileSystems = {
    "/".options = [ "compress=lzo" ];
    "/home".options = [ "compress=lzo" ];
    "/nix".options = [ "compress=lzo" "noatime" ];
    "/swap".options = [ "compress=lzo" ];
  };

  services.xserver = {
    layout = "us";
    xkbVariant = "dvp";
    xkbOptions = "caps:escape, grp:alt_shift_toggle";
  };
  console.useXkbConfig = true; 

  programs.fish.enable = true;
  programs.neovim.enable = true;
  programs.hyprland.enable = true;
  programs.git.enable = true;

  virtualisation.docker.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.greetd = {
    enable = true;
    settings = rec {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd ${pkgs.hyprland}/bin/Hyprland -r -t";
      };
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = true;
    };
  };
  programs.ssh.startAgent = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  fonts.enableDefaultPackages = false;
  fonts = {
    packages = with pkgs; [
      (nerdfonts.override {
        fonts = [
          "Hack"
        ];
      })
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "Hack" ];
      };
    };
  };

  users.users = builtins.listToAttrs ( builtins.map ( user: {
      name = user.username;
      value = mkSystemUser {
        inherit (user) username groups;
      };
    }) users );

  system.stateVersion = "23.05";
}
