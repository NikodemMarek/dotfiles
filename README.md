# infra

Kubernetes manifests for my clusters.

The cluster is managed by [Flux](https://fluxcd.io/) (`clusters/dijkstra/flux-system`), so configs are never applied manually - changes are committed and pushed, and Flux reconciles them every few minutes.

To apply the changes instantly:
```sh
flux reconcile kustomization flux-system --namespace flux-system --with-source
```

## Secrets

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using the cluster's age key (see `.sops.yaml`); Flux decrypts them when applying. Encrypted files must match `*.enc.*`, e.g. `secret.enc.yaml`. To create one, write a plain `Secret` manifest with `stringData`, then encrypt it in place with the devenv script:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
  namespace: myapp
type: Opaque
stringData:
  api_key: changeme
```

```sh
mksecret clusters/dijkstra/<app>/secret.enc.yaml
```

To change an existing secret, edit it with `sops clusters/dijkstra/<app>/secret.enc.yaml` (requires the age private key).
