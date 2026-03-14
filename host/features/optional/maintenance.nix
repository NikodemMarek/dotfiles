{config, ...}: {
  sops.secrets."users/maintenance/password" = {
    neededForUsers = true;
  };

  nix.settings.trusted-users = ["maintenance" "@wheel"];

  users = {
    users = {
      root.hashedPassword = "!";
      maintenance = {
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets."users/maintenance/password".path;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keyFiles = [
          ../../yenn/user_nikodem_ssh_id_ed25519.pub
        ];
      };
    };
  };
}
