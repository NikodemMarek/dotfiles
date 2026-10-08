# Applies the age key Flux decrypts the cluster's sops manifests with as secret
# flux-system/sops-age. Enable it on the k3s server only: moving the server role
# means moving the flag. The key is `FLUX_SOPS_AGE_KEY` in the secretspec.toml
# profile `dijkstra` and must belong to &dijkstra_cluster in .sops.yaml.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.flux-sops-age;

  recipient = let
    found = lib.findFirst (m: m != null) null (map
      (builtins.match ".*&dijkstra_cluster (age1[0-9a-z]+).*")
      (lib.splitString "\n" (builtins.readFile ../../.sops.yaml)));
  in
    if found == null
    then throw "flux-sops-age: no `&dijkstra_cluster age1...` recipient found in .sops.yaml"
    else lib.head found;
in {
  options.services.flux-sops-age.enable = lib.mkEnableOption "applying the Flux sops-age key to the k3s cluster";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.k3s.enable && config.services.k3s.role == "server";
        message = "services.flux-sops-age applies the key through the local k3s API, so it must be enabled on the k3s server only (services.k3s.enable = true, services.k3s.role = \"server\").";
      }
    ];

    secrets.flux_sops_age_key.profile = "dijkstra";

    systemd.services.flux-sops-age = {
      description = "Apply the Flux sops-age key to the cluster";
      after = ["k3s.service"];
      requires = ["k3s.service"];
      wantedBy = ["multi-user.target"];
      environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      path = [config.services.k3s.package pkgs.age];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # must stay below deploy-rs's activation timeout (240s default), so a stuck
        # start fails the switch instead of deploy-rs timing out first
        TimeoutStartSec = "3min";
      };
      script = ''
        key=${config.secrets.flux_sops_age_key.path}

        # the key must be the cluster identity Flux decrypts with, else every reconcile fails
        if [ "$(age-keygen -y "$key")" != "${recipient}" ]; then
          echo "flux_sops_age_key is not &dijkstra_cluster from .sops.yaml" >&2
          exit 1
        fi

        until k3s kubectl get --raw=/readyz > /dev/null 2>&1; do sleep 5; done

        k3s kubectl create namespace flux-system --dry-run=client -o yaml \
          | k3s kubectl apply --server-side --field-manager=flux-sops-age -f -
        k3s kubectl -n flux-system create secret generic sops-age --from-file=age.agekey="$key" --dry-run=client -o yaml \
          | k3s kubectl apply --server-side --force-conflicts --field-manager=flux-sops-age -f -
      '';
    };
  };
}
