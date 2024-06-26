{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../../../home
    ../../../../home/neovim
    ../../../../home/hyprland

    ../../../../home/impermanence.nix
    ../../../../home/ssh.nix
  ];

  home.username = "nm1";

  settings = {
    hostname = "LP-043";
    monitors = [
      {
        name = "eDP-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 0;
        y = 0;
        transform = 0;
      }
      {
        name = "DP-3";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 0;
        y = -1080;
        transform = 0;
      }
      {
        name = "DP-4";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 1920;
        y = -1260;
        transform = 3;
      }
    ];
  };

  sops.secrets = {
    "users/nm1/openfortivpn/host" = {};
    "users/nm1/openfortivpn/port" = {};
    "users/nm1/openfortivpn/username" = {};
    "users/nm1/openfortivpn/password" = {};
    "users/nm1/openfortivpn/realm" = {};
    "users/nm1/openfortivpn/trusted_cert" = {};
    "users/nm1/openfortivpn/user_cert" = {
      sopsFile = ../../openfortivpn_cert.pem;
      format = "binary";
    };
    "users/nm1/openfortivpn/user_key" = {
      sopsFile = ../../openfortivpn_key.pem;
      format = "binary";
    };
  };

  services = {
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT0/capacity";
      statusPath = "/sys/class/power_supply/BAT0/status";
    };

    openfortivpn = let
      # FIXME: Temporary solution that only works if secrets are already present on the host.
      readIfExists = path:
        if builtins.pathExists path
        then builtins.readFile path
        else null;
    in {
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

  home.packages = with pkgs; [
    rocketchat-desktop
    zathura
    kooha
    obs-studio
    xh
    # pnpm
    bun
    jdk11
    sshpass
    maven
    remmina
    nodejs_22
    google-chrome
    android-studio
    jetbrains.idea-ultimate
    jetbrains.pycharm-community
    jetbrains.datagrip
  ];
}
