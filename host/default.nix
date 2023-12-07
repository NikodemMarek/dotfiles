{ inputs, outputs, lib, config, pkgs, hostname, users, settings, ... }:
let
  mkSystemUser = { username, groups, ... }: {
    initialPassword = username;
    isNormalUser = true;
    extraGroups = groups;
    shell = pkgs.fish;
  };
in
{
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
  };

  programs.fish.enable = true;
  programs.neovim.enable = true;
  programs.hyprland.enable = true;
  programs.git.enable = true;

  virtualisation.docker.enable = true;

  # this is necesary for gtklock to work
  security.pam.services.gtklock = { };

  hardware.bluetooth = {
    enable = settings.bluetooth;
    powerOnBoot = settings.bluetooth;
  };

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

  users.users = builtins.listToAttrs (builtins.map
    (user: {
      name = user.username;
      value = mkSystemUser {
        inherit (user) username groups;
      };
    })
    users);

  system.stateVersion = "23.05";
}
