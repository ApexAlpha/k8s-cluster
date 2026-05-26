# Hermes

Hermes runs as a private app at `https://hermes.k8s.hu.ls`, protected by the cluster-wide Authentik Traefik middleware.

Provider credentials are intentionally not committed. To add them, create a sealed secret named `hermes-provider-keys` in the `hermes` namespace with the environment variables Hermes should receive, then add that sealed-secret file to `kustomization.yaml` so Argo CD manages it.

Example:

```bash
kubectl create secret generic hermes-provider-keys -n hermes \
  --from-literal=OPENAI_API_KEY=<key> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system \
           --controller-name sealed-secrets-controller \
           --format yaml > homelab/hermes/hermes-provider-keys-sealed.yaml
```
