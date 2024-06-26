{
  lib,
  config,
  ...
}: {
  sops.secrets."users/${config.home.username}/ssh_ed25519_priv" = {};

  home.file = {
    ".ssh/id_ed25519.pub".source = ../setups/${config.settings.hostname}/users/${config.home.username}/id_ed25519.pub;
    ".ssh/id_ed25519" = lib.mkIf (builtins.pathExists config.sops.secrets."users/${config.home.username}/ssh_ed25519_priv".path) {
      source = config.sops.secrets."users/${config.home.username}/ssh_ed25519_priv".path;
    };
  };
}
