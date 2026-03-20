{config, ...}: let
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
    ./programs.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  services = {
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT0/capacity";
      statusPath = "/sys/class/power_supply/BAT0/status";
    };
  };

  home = {
    username = "nm1";
    sessionVariables = {
      DOMAIN_NEXUS_LOGIN = readIfExists config.sops.secrets."users/nm1/domain_login".path;
      DOMAIN_NEXUS_PASSWORD = readIfExists config.sops.secrets."users/nm1/domain_password".path;
      DEPLOY_DOCKER = readIfExists config.sops.secrets."users/nm1/gitlab_token".path;
    };
  };
}
