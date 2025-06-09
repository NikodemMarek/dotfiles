{
  lib,
  pkgs,
  config,
  ...
}: let
  # FIXME: Temporary solution that only works if secrets are already present on the host.
  readIfExists = path:
    if builtins.pathExists path
    then builtins.readFile path
    else null;
in {
  imports = [
    ../features/hyprland

    ../features/neovim.nix
    ../features/ssh.nix
    ../features/docker.nix
    ../features/zen-browser.nix
    ../features/coding.nix
  ];

  services = {
    eww = {
      enable = true;
      monitor = {
        width = 1920;
        height = 1080;
      };
      windows = {
        powermenu.grid = [12 0 4 2];
        system = {
          grid = [0 2 4 3];
          args = {
            battery = "true";
          };
        };
        clock.grid = [4 2 8 5];
        music.grid = [0 5 4 2];
        volume.grid = [4 0 4 2];
      };
    };
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT0/capacity";
      statusPath = "/sys/class/power_supply/BAT0/status";
    };
    openfortivpn = {
      enable = true;
      autorun = true;
      port =
        if builtins.pathExists config.sops.secrets."users/nm1/openfortivpn/port".path
        then builtins.readFile config.sops.secrets."users/nm1/openfortivpn/port".path
        else 8443;

      host = readIfExists config.sops.secrets."users/nm1/openfortivpn/host".path;
      username = readIfExists config.sops.secrets."users/nm1/openfortivpn/username".path;
      password = readIfExists config.sops.secrets."users/nm1/openfortivpn/password".path;
      realm = readIfExists config.sops.secrets."users/nm1/openfortivpn/realm".path;
      trusted-cert = readIfExists config.sops.secrets."users/nm1/openfortivpn/trusted_cert".path;

      user-cert = config.sops.secrets."users/nm1/openfortivpn/user_cert".path;
      user-key = config.sops.secrets."users/nm1/openfortivpn/user_key".path;
    };
  };

  programs = {
    git = {
      userEmail = "nikodem.marek@softnet.com.pl";
      userName = "nm1";
    };
  };

  home = {
    file = {
      ".m2/settings.xml".source = config.sops.secrets."users/nm1/m2_settings".path;
      ".gradle/gradle.properties".source = config.sops.secrets."users/nm1/gradle_properties".path;
    };
    sessionVariables = {
      JAVA_8_HOME = "${pkgs.jdk8}";
      JAVA_11_HOME = "${pkgs.jdk11}";
      JAVA_21_HOME = "${pkgs.jdk21}";
      JAVA_23_HOME = "${pkgs.jdk23}";
      DOMAIN_NEXUS_LOGIN = readIfExists config.sops.secrets."users/nm1/domain_login".path;
      DOMAIN_NEXUS_PASSWORD = readIfExists config.sops.secrets."users/nm1/domain_password".path;
    };
    packages = with pkgs; [
      zathura
      kooha
      pnpm
      jdk23
      sshpass
      maven
      remmina
      nodejs_22
      google-chrome
      android-studio
      jetbrains.idea-ultimate
      postman
      python3
      python313Packages.pip
      nushell
      dbeaver-bin
      gcc
      oracle-instantclient
    ];
  };

  wayland.windowManager.hyprland.settings.exec-once = [
    "[workspace 1 silent] ${lib.getExe pkgs.google-chrome}"
    "[workspace 2 silent] ${lib.getExe config.programs.wezterm.package}"
  ];
}
