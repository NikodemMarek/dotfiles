{
  users,
  hostname,
  ...
}: {
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    # FIXME: This does not seem right
    age = {
      sshKeyPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];
    };
  };

  users.mutableUsers = false;
  sops.secrets =
    {
      "config/openai_api_key" = {
        mode = "0440";
        group = "users";
      };
    }
    // builtins.listToAttrs
    (builtins.map
      (user: {
        name = "hosts/${hostname}/users/${user.username}/password";
        value = {
          sopsFile = ../../secrets.yaml;
          neededForUsers = true;
        };
      })
      users)
    // builtins.listToAttrs
    (builtins.map
      (user: {
        name = "hosts/${hostname}/users/${user.username}/ed_25519_priv";
        value = {
          sopsFile = ../../secrets.yaml;
          mode = "0400";
          owner = user.username;
        };
      })
      users);
}
