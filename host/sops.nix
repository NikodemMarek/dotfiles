{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  users,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = with pkgs; [
    rage
  ];

  sops = {
    defaultSopsFile = ../secrets.yaml;
    defaultSopsFormat = "yaml";

    # FIXME: This does not seem right
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
  };

  sops.secrets =
    {
      "configs/openai_api_key" = {
        mode = "0440";
        group = "users";
      };
      "passwords/music" = {
        sopsFile = ../secrets.yaml;
        neededForUsers = true;
      };
    }
    // builtins.listToAttrs
    (builtins.map
      (user: {
        name = "passwords/${user.username}";
        value = {
          sopsFile = ../secrets.yaml;
          neededForUsers = true;
        };
      })
      users);
}
