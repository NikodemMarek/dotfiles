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
    ../../secrets.nix

    ../../../../home
    ../../../../secrets
    ../../../../home/hyprland

    ../../../../home/neovim.nix
    ../../../../home/impermanence.nix
    ../../../../home/ssh.nix
    ../../../../home/docker.nix
    ../../../../home/bun.nix
  ];

  services = {
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
    packages = with pkgs; [
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
      postman
    ];
    persistence."/persist/${config.home.homeDirectory}".directories = [
      ".config/Rocket.Chat"
      ".config/JetBrains"

      ".local/share/JetBrains"
      ".gradle/caches/modules-2/files-2.1"

      ".config/google-chrome"
      ".cache/google-chrome"
    ];
  };

  programs.bun.settings = {
    install."@softnet-ng" = {
      url = readIfExists config.sops.secrets."users/nm1/npm/url".path;
      username = readIfExists config.sops.secrets."users/nm1/npm/username".path;
      password = readIfExists config.sops.secrets."users/nm1/npm/password".path;
      https-proxy = readIfExists config.sops.secrets."users/nm1/npm/url".path;
      noproxy = readIfExists config.sops.secrets."users/nm1/npm/url".path;
      strict-ssl = true;
    };
  };

  wayland.windowManager.hyprland.settings.exec-once = [
    "[workspace 1 silent] ${pkgs.rocketchat-desktop}/bin/rocketchat-desktop"
    "[workspace 2 silent] ${pkgs.google-chrome}/bin/google-chrome-stable"
    "[workspace 3 silent] ${pkgs.wezterm}/bin/wezterm"
  ];
}
