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
  };
  console.useXkbConfig = true; 

  programs.fish.enable = true;
  programs.neovim.enable = true;
  programs.hyprland.enable = true;
  programs.git.enable = true;

  virtualisation.docker.enable = true;

  environment.etc = {
    "greetd/hyprregreet.conf".text = ''
      misc {
        disable_hyprland_logo = true
        # disable_hypr_chan = true
      }
      exec-once = ${pkgs.greetd.regreet}/bin/regreet; hyprctl dispatch exit
    '';
    "greetd/regreetbg.png".source = ./wallpaper.png;
  };
  programs.regreet = {
    enable = true;
    settings = {
      background = {
        path = "/etc/greetd/regreetbg.png";
        fit = "Contain";
      };
      GTK.application_prefer_dark_theme = true;
    };
  };
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.hyprland}/bin/Hyprland --config /etc/greetd/hyprregreet.conf";
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
