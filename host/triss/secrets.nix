{
  secrets = {
    host_ssh_ed25519_priv = {};
    # Hash with `mkpasswd`
    users_maintenance_password = {
      neededForUsers = true;
    };
    # Generate with `k3s token create`
    k3s_token = {};
    # Assembled from k3s_tailscale_auth_key
    k3s_vpn_auth = {};
  };
}
