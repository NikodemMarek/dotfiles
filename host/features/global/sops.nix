# Provider for the secrets contract (modules/host/secrets.nix): decrypts
# host/<host>/secrets.yaml with sops-nix.
# This is the only place that should know secrets come from sops. Secret names
# are flat top-level keys in secrets.yaml.
{
  lib,
  config,
  ...
}: let
  # Secrets that are assembled from other sops secrets, not stored directly
  derived = ["k3s_vpn_auth"];
  stored = builtins.removeAttrs config.secrets derived;
in
  lib.mkMerge [
    {
      sops = {
        defaultSopsFile = ../../${config.networking.hostName}/secrets.yaml;
        defaultSopsFormat = "yaml";

        age = {
          sshKeyPaths = ["/persist/data/etc/ssh/ssh_host_ed25519_key"];
        };
      };

      sops.secrets = lib.mapAttrs (_: s:
        {
          inherit (s) owner group mode neededForUsers;
        }
        // lib.optionalAttrs (!s.neededForUsers) {
          inherit (s) path;
        })
      stored;

      persist.generated.directories = ["/var/lib/sops-nix"];
    }

    # TODO: Remove when a better way to generate secrets is possible.
    (lib.mkIf (config.secrets ? k3s_vpn_auth) {
      # Generate in tailscale console Settings > Keys
      sops.secrets.k3s_tailscale_auth_key = {};

      sops.templates.k3s_vpn_auth = {
        content = "name=tailscale,joinKey=${config.sops.placeholder.k3s_tailscale_auth_key}";
        inherit (config.secrets.k3s_vpn_auth) path owner group mode;
      };
    })
  ]
