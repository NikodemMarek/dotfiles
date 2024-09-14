{
  lib,
  config,
  ...
}: {
  home = {
    file = {
      ".ssh/id_ed25519.pub".source = ../../host/${config.settings.hostname}/user_${config.home.username}_ssh_id_ed25519.pub;
      ".ssh/id_ed25519" = lib.mkIf (builtins.pathExists config.sops.secrets."users/${config.home.username}/ssh_id_ed25519".path) {
        source = config.sops.secrets."users/${config.home.username}/ssh_id_ed25519".path;
      };
    };
    persistence."/persist/${config.home.homeDirectory}".directories = [
      ".ssh"
    ];
  };
}
