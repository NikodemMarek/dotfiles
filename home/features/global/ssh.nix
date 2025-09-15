{config, ...}: let
  identityFile = config.sops.secrets."users/${config.home.username}/ssh_id_ed25519".path;
in {
  home.file = {
    ".ssh/id_ed25519".source = identityFile;
  };

  programs.ssh = {
    enable = true;
  };
}
