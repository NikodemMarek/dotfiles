{
  sops.secrets = {
    "users/maintenance/password" = {
      neededForUsers = true;
    };
    "users/music/password" = {
      neededForUsers = true;
    };
  };
}
