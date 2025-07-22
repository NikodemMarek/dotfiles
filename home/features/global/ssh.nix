{config, ...}: let
  identityFile = config.sops.secrets."users/${config.home.username}/ssh_id_ed25519".path;
in {
  home.file = {
    # ".ssh/id_ed25519.pub".source = ../../../host/${host-config.networking.hostName}/user_${config.home.username}_ssh_id_ed25519.pub;
    ".ssh/id_ed25519".source = identityFile;
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "nikodem@dorm.desktop" = {
        inherit identityFile;
        hostname = "dorm.desktop";
        user = "nikodem";
      };
      "nikodem@dorm.laptop" = {
        inherit identityFile;
        hostname = "dorm.laptop";
        user = "nikodem";
      };
      "nm1@dorm.LP-043" = {
        inherit identityFile;
        hostname = "dorm.LP-043";
        user = "nm1";
      };

      "nikodem@zerotier.desktop" = {
        inherit identityFile;
        hostname = "zerotier.desktop";
        user = "nikodem";
      };
      "nikodem@zerotier.laptop" = {
        inherit identityFile;
        hostname = "zerotier.laptop";
        user = "nikodem";
      };
      "nm1@zerotier.LP-043" = {
        inherit identityFile;
        hostname = "zerotier.LP-043";
        user = "nm1";
      };
    };
  };
}
