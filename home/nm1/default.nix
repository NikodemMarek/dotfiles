{
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
    ./kanshi.nix

    ../features/hyprland

    ../features/neovim.nix
    ../features/impermanence.nix
    ../features/ssh.nix
    ../features/docker.nix
    ../features/bun.nix
  ];

  services = {
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT0/capacity";
      statusPath = "/sys/class/power_supply/BAT0/status";
    };
    # openfortivpn = {
    #   enable = true;
    #   autorun = true;
    #   port =
    #     if builtins.pathExists config.sops.secrets."users/nm1/openfortivpn/port".path
    #     then builtins.readFile config.sops.secrets."users/nm1/openfortivpn/port".path
    #     else 8443;
    #
    #   host = readIfExists config.sops.secrets."users/nm1/openfortivpn/host".path;
    #   username = readIfExists config.sops.secrets."users/nm1/openfortivpn/username".path;
    #   password = readIfExists config.sops.secrets."users/nm1/openfortivpn/password".path;
    #   realm = readIfExists config.sops.secrets."users/nm1/openfortivpn/realm".path;
    #   trusted-cert = readIfExists config.sops.secrets."users/nm1/openfortivpn/trusted_cert".path;
    #
    #   user-cert = config.sops.secrets."users/nm1/openfortivpn/user_cert".path;
    #   user-key = config.sops.secrets."users/nm1/openfortivpn/user_key".path;
    # };
  };

  programs = {
    git = {
      userEmail = "nikodem.marek@softnet.com.pl";
      userName = "nm1";
    };
  };

  home = {
    # file.".m2/settings.xml".source = config.sops.secrets."users/nm1/m2_settings".path;
    packages = with pkgs; [
      rocketchat-desktop
      zathura
      kooha
      obs-studio
      xh
      pnpm
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
      anysync
    ];
    persistence."/persist/generated/${config.home.homeDirectory}".directories = [
      ".config/Rocket.Chat"
      ".config/JetBrains"

      ".local/share/JetBrains"
    ];
  };

  programs.bun.settings = {
    # install."@softnet-ng" = {
    #   url = readIfExists config.sops.secrets."users/nm1/npm/url".path;
    #   username = readIfExists config.sops.secrets."users/nm1/npm/username".path;
    #   password = readIfExists config.sops.secrets."users/nm1/npm/password".path;
    #   https-proxy = readIfExists config.sops.secrets."users/nm1/npm/url".path;
    #   noproxy = readIfExists config.sops.secrets."users/nm1/npm/url".path;
    #   strict-ssl = true;
    # };
  };

  wayland.windowManager.hyprland.settings.exec-once = [
    "[workspace 1 silent] ${pkgs.rocketchat-desktop}/bin/rocketchat-desktop"
    "[workspace 2 silent] ${pkgs.firefox}/bin/firefox"
    "[workspace 3 silent] ${pkgs.wezterm}/bin/wezterm"
  ];
}
