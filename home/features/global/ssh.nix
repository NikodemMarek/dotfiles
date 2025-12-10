{config, ...}: let
  identityFile = config.sops.secrets."users/${config.home.username}/ssh_id_ed25519".path;
in {
  home.file = {
    # ".ssh/id_ed25519.pub".source = ../../../host/${host-config.networking.hostName}/user_${config.home.username}_ssh_id_ed25519.pub;
    ".ssh/id_ed25519".source = identityFile;
  };

  programs.ssh = {
    enable = true;
  };
}
