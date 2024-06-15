{
  lib,
  config,
  hostname,
  ...
}: {
  config = lib.mkIf (builtins.pathExists /run/secrets/users/${config.settings.username}/ssh_ed25519_priv) {
    sops.secrets."users/${config.settings.username}/ssh_ed25519_priv" = {};

    home.file = {
      ".ssh/id_ed25519.pub".source = ../../host/${hostname}/users/${config.settings.username}/id_ed25519.pub;
      ".ssh/id_ed25519".source = /run/secrets/users/${config.settings.username}/ssh_ed25519_priv;
    };
  };
}
