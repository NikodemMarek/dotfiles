{
  lib,
  config,
  ...
}: {
  sops = {
    defaultSopsFile = ../${config.networking.hostName}/secrets.yaml;
    defaultSopsFormat = "yaml";

    # FIXME: This does not seem right
    age = {
      sshKeyPaths = ["/persist/data/etc/ssh/ssh_host_ed25519_key"];
    };
  };

  sops.secrets =
    {
      "host_ssh_ed25519_priv" = {};
    }
    // builtins.listToAttrs (lib.lists.flatten
      (
        builtins.map
        (user: [
          {
            name = "users/${user.home.username}/password";
            value = {
              neededForUsers = true;
            };
          }
        ])
        (lib.attrValues config.home-manager.users) # Has to be list from home-manager, because otherwise it would also take system users (eg. root)
      ));

  environment.etc = {
    "ssh/ssh_host_ed25519_key".source = config.sops.secrets."host_ssh_ed25519_priv".path;
    "ssh/ssh_host_ed25519_key.pub".source = ../${config.networking.hostName}/ssh_host_ed25519_key.pub;
  };
}
