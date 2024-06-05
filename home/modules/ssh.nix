{
  lib,
  hostname,
  username,
  ...
}: {
  config = lib.mkIf (builtins.pathExists /run/secrets/hosts/${hostname}/users/${username}/ssh_ed25519_priv) {
    sops.secrets."hosts/${hostname}/users/${username}/ssh_ed25519_priv" = {};

    home.file = {
      ".ssh/id_ed25519.pub".source = ../../host/${hostname}/${username}_id_ed25519.pub;
      ".ssh/id_ed25519".source = "/run/secrets/hosts/${hostname}/users/${username}/ssh_ed25519_priv";
    };
  };
}
