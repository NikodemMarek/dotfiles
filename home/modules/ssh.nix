{
  lib,
  hostname,
  username,
  ...
}: {
  config = lib.mkIf (builtins.pathExists /run/secrets/users/${username}/ssh_ed25519_priv) {
    sops.secrets."users/${username}/ssh_ed25519_priv" = {};

    home.file = {
      ".ssh/id_ed25519.pub".source = ../${hostname}/${username}_id_ed25519.pub;
      ".ssh/id_ed25519".source = "/run/secrets/users/${username}/ssh_ed25519_priv";
    };
  };
}
