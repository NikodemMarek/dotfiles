{
  inputs,
  lib,
  config,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../setups/${config.networking.hostName}/secrets.yaml;
    defaultSopsFormat = "yaml";

    # FIXME: This does not seem right
    age = {
      sshKeyPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];
    };
  };

  sops.secrets =
    {
      "config/openai_api_key" = {
        mode = "0440";
        group = "users";
      };
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
          {
            name = "users/${user.home.username}/ssh_ed25519_priv";
            value = {};
          }
        ])
        (lib.attrValues config.home-manager.users)
      ));
}
