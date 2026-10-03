{config, ...}: {
  # The hash must exist before users are created, otherwise the deploy user
  # has no password and interactive sudo breaks
  secretsRequired.users_maintenance_password.neededForUsers = true;

  nix.settings.trusted-users = ["maintenance" "@wheel"];

  users = {
    users = {
      root.hashedPassword = "!";
      maintenance = {
        isNormalUser = true;
        hashedPasswordFile = config.secrets.users_maintenance_password.path;
        extraGroups = ["wheel" "docker"];
        openssh.authorizedKeys.keyFiles = [
          ../../yenn/user_nikodem_ssh_id_ed25519.pub
        ];
      };
    };
  };
}
