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
  sops.age.keyFile = "/home/nikodem/.config/sops/age/keys.txt";

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
