{ inputs, outputs, lib, config, pkgs, users, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = with pkgs; [
    age
  ];

  sops.defaultSopsFile = ../secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  # FIXME: This does not seem right
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  sops.secrets = builtins.listToAttrs
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
