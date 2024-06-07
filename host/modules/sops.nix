{
  inputs,
  hostname,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../${hostname}/secrets.yaml;
    defaultSopsFormat = "yaml";

    # FIXME: This does not seem right
    age = {
      sshKeyPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];
    };
  };

  sops.secrets = {
    "config/openai_api_key" = {
      mode = "0440";
      group = "users";
    };
  };
}
