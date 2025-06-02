{
  host-config,
  config,
  ...
}: {
  home.file = {
    ".ssh/id_ed25519.pub".source = ../../host/${host-config.networking.hostName}/user_${config.home.username}_ssh_id_ed25519.pub;
    ".ssh/id_ed25519".source = config.sops.secrets."users/${config.home.username}/ssh_id_ed25519".path;
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "nikodem@dorm.desktop" = {
        hostname = "dorm.desktop";
        user = "nikodem";
        identityFile = "${config.home.file.".ssh/id_ed25519".source}";
      };
      "nikodem@dorm.laptop" = {
        hostname = "dorm.laptop";
        user = "nikodem";
        identityFile = "${config.home.file.".ssh/id_ed25519".source}";
      };
      "nm1@dorm.LP-043" = {
        hostname = "dorm.LP-043";
        user = "nm1";
        identityFile = "${config.home.file.".ssh/id_ed25519".source}";
      };

      "nikodem@zerotier.desktop" = {
        hostname = "zerotier.desktop";
        user = "nikodem";
        identityFile = "${config.home.file.".ssh/id_ed25519".source}";
      };
      "nikodem@zerotier.laptop" = {
        hostname = "zerotier.laptop";
        user = "nikodem";
        identityFile = "${config.home.file.".ssh/id_ed25519".source}";
      };
      "nm1@zerotier.LP-043" = {
        hostname = "zerotier.LP-043";
        user = "nm1";
        identityFile = "${config.home.file.".ssh/id_ed25519".source}";
      };
    };
  };
}
