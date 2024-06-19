users: {
  pkgs,
  config,
  ...
}: let
  mkSystemUser = {
    username,
    groups,
    ...
  }: {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."users/${username}/password".path;
    extraGroups = groups;
    shell = pkgs.fish;
  };
in {
  sops.secrets =
    builtins.listToAttrs
    ((builtins.map
        (user: {
          name = "users/${user.username}/password";
          value = {
            sopsFile = ../setups/${config.networking.hostName}/secrets.yaml;
            neededForUsers = true;
          };
        })
        users)
      ++ (builtins.map
        (user: {
          name = "users/${user.username}/ssh_ed25519_priv";
          value = {
            sopsFile = ../setups/${config.networking.hostName}/secrets.yaml;
            mode = "0400";
            owner = user.username;
          };
        })
        users));

  users = {
    mutableUsers = false;
    users = builtins.listToAttrs (builtins.map
      (user: {
        name = user.username;
        value = mkSystemUser {
          inherit (user) username groups;
        };
      })
      users);
  };

  home-manager.users = builtins.listToAttrs (builtins.map
    (user: {
      name = user.username;
      value = import ../setups/${config.networking.hostName}/users/${user.username};
    })
    users);
}
