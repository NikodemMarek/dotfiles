{
  lib,
  config,
  hostname,
  ...
}: {
  config = lib.mkIf (builtins.pathExists /run/secrets/users/${config.home.username}/ssh_ed25519_priv) {
    sops.secrets."users/${config.home.username}/ssh_ed25519_priv" = {};

    home.file = {
      ".ssh/id_ed25519.pub".source = ../../host/${hostname}/users/${config.home.username}/id_ed25519.pub;
      ".ssh/id_ed25519".source = /run/secrets/users/${config.home.username}/ssh_ed25519_priv;
    };
  };
}
