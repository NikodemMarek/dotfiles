{
  pkgs,
  users,
  hostname,
  ...
}: {
  environment.systemPackages = with pkgs; [
    rage
  ];

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
      # "configs/openai_api_key" = {
      #   mode = "0440";
      #   group = "users";
      # };
    }
    // builtins.listToAttrs
    (builtins.map
      (user: {
        name = "${hostname}/users/${user.username}/password";
        value = {
          sopsFile = ../../secrets.yaml;
          neededForUsers = true;
        };
      })
      users);
}
