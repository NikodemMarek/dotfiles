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
    ../features
    ../features/global

    ./secrets.nix
    ./kanshi.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  services = {
    eww = {
      enable = true;
      monitor = {
        width = 1920;
        height = 1080;
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
    aichat.settings = {
      model = "claude:claude-3-7-sonnet-20250219";
      clients = [
        {
          type = "claude";
          api_key = readIfExists config.sops.secrets."anthropic/api_key".path;
        }
      ];
    };
  };

  home = {
    username = "nm1";
    file = {
      ".m2/settings.xml".source = config.sops.secrets."users/nm1/m2_settings".path;
      ".gradle/gradle.properties".source = config.sops.secrets."users/nm1/gradle_properties".path;
      ".ssh/id_ed25519.pub".source = ./user_nm1_ssh_id_ed25519.pub;
      ".ssh/id_ed25519".source = config.sops.secrets."users/${config.home.username}/ssh_id_ed25519".path;
    };
    sessionVariables = {
      JAVA_8_HOME = "${pkgs.jdk8}";
      JAVA_11_HOME = "${pkgs.jdk11}";
      JAVA_21_HOME = "${pkgs.jdk21}";
      JAVA_25_HOME = "${pkgs.jdk25}";
      DOMAIN_NEXUS_LOGIN = readIfExists config.sops.secrets."users/nm1/domain_login".path;
      DOMAIN_NEXUS_PASSWORD = readIfExists config.sops.secrets."users/nm1/domain_password".path;
      GITLAB_TOKEN = readIfExists config.sops.secrets."users/nm1/gitlab_token".path;
      DEPLOY_DOCKER = readIfExists config.sops.secrets."users/nm1/gitlab_token".path;
    };
    packages = [
      (pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
        gke-gcloud-auth-plugin
      ]))
      pkgs.kubectl
      pkgs.sshpass
      pkgs.remmina
      pkgs.google-chrome
      pkgs.android-studio
      pkgs.jetbrains.idea-ultimate
      pkgs.dbeaver-bin
      pkgs.oracle-instantclient
      pkgs.glab
      pkgs.rainfrog
      pkgs.claude-code
      pkgs.gemini-cli
    ];
  };
}
