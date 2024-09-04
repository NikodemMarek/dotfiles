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
      "host_ssh_ed25519_priv" = {};
      "api_keys/youtube" = {
        mode = "0440";
        group = "users";
      };
      "api_keys/openai" = {
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

  environment.etc = {
    "ssh/ssh_host_ed25519_key".source = config.sops.secrets."host_ssh_ed25519_priv".path;
    "ssh/ssh_host_ed25519_key.pub".source = ../setups/${config.networking.hostName}/ssh_host_ed25519_key.pub;
  };
}
