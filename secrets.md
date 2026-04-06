# Secrets Setup Guide

All secrets are managed via [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets).
Sealed secrets are safe to commit to git — they can only be decrypted by the controller in the cluster.

## 1. Install kubeseal CLI

```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.3/kubeseal-0.27.3-linux-amd64.tar.gz
tar -xvzf kubeseal-0.27.3-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

Verify the controller is running:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

## 2. How to seal a secret

```bash
kubectl create secret generic <name> -n <namespace> \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system \
           --controller-name sealed-secrets-controller \
           --format yaml > homelab/<app>/<name>-sealed.yaml
```

Then add the file to the app's `kustomization.yaml` and commit.

## 3. Order of operations

1. Sync `sealed-secrets` app → controller starts
2. Sync `cnpg-operator` + `postgres-shared` → CNPG starts
3. Get the CNPG `app` user password (used by most apps):
   ```bash
   kubectl get secret postgres-shared-app -n database -o jsonpath='{.data.password}' | base64 -d
   ```
4. Seal all secrets below using that password where `<cnpg-app-password>` is referenced
5. Commit sealed secrets to git
6. Sync remaining apps

---

## Secrets by namespace

### database (CNPG barman backups)

Uses the same JuiceFS gateway credentials to write backups to the `postgres-backups` bucket via the S3 gateway.

```bash
kubectl create secret generic cnpg-barman-credentials -n database \
  --from-literal=access-key=GK8bedc300d10921b4f7e57472 \
  --from-literal=secret-key=ec18c41709d06868d0de288916eaf444973ec8c7cd0938eeab3f1d52c59e3e05 \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/cnpg/cluster/cnpg-barman-credentials-sealed.yaml
```

Add to `homelab/cnpg/cluster/kustomization.yaml`:
```yaml
  - cnpg-barman-credentials-sealed.yaml
```

---

### cert-manager

```bash
kubectl create secret generic cloudflare-api-token -n cert-manager \
  --from-literal=api-token=<cloudflare-api-token> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/cert-manager/cloudflare-api-token-sealed.yaml
```

Add to `homelab/cert-manager/kustomization.yaml`:
```yaml
  - cloudflare-api-token-sealed.yaml
```

---

### authentik

```bash
kubectl create secret generic authentik-secret -n authentik \
  --from-literal=secret_key=$(openssl rand -hex 32) \
  --from-literal=pg_pass=<cnpg-app-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/authentik/authentik-secret-sealed.yaml
```

Add to `homelab/authentik/kustomization.yaml`:
```yaml
  - authentik-secret-sealed.yaml
```

---

### kube-system (JuiceFS)

> Set up Garage first and have your key ID and secret ready.

```bash
kubectl create secret generic juicefs-secret -n kube-system \
  --from-literal=name=juicefs \
  --from-literal=metaurl="postgres://app:<cnpg-app-password>@postgres-shared-rw.database.svc.cluster.local/juicefs" \
  --from-literal=storage=s3 \
  --from-literal=bucket="http://garage-s3.garage.svc.cluster.local:3900/juicefs-data" \
  --from-literal=access-key=<garage-key-id> \
  --from-literal=secret-key=<garage-secret-key> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/juicefs/juicefs-secret-sealed.yaml

kubectl create secret generic juicefs-gateway-credentials -n kube-system \
  --from-literal=access-key=<garage-key-id> \
  --from-literal=secret-key=<garage-secret-key> \
  --from-literal=webdav-user=admin \
  --from-literal=webdav-password=<choose-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/juicefs/juicefs-gateway-credentials-sealed.yaml
```

Add both to `homelab/juicefs/kustomization.yaml`:
```yaml
  - juicefs-secret-sealed.yaml
  - juicefs-gateway-credentials-sealed.yaml
```

---

### monitoring

```bash
kubectl create secret generic grafana-admin -n monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=<choose-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/monitoring/grafana-admin-sealed.yaml

kubectl create secret generic grafana-db -n monitoring \
  --from-literal=password=<cnpg-app-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/monitoring/grafana-db-sealed.yaml
```

Add both to `homelab/monitoring/kustomization.yaml`:
```yaml
  - grafana-admin-sealed.yaml
  - grafana-db-sealed.yaml
```

---

### vaultwarden

```bash
kubectl create secret generic vaultwarden-db -n vaultwarden \
  --from-literal=DATABASE_URL="postgresql://app:<cnpg-app-password>@postgres-shared-rw.database.svc/vaultwarden" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/vaultwarden/vaultwarden-db-sealed.yaml

kubectl create secret generic vaultwarden-admin -n vaultwarden \
  --from-literal=ADMIN_TOKEN=$(openssl rand -base64 48) \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/vaultwarden/vaultwarden-admin-sealed.yaml
```

Add both to `homelab/vaultwarden/kustomization.yaml`:
```yaml
  - vaultwarden-db-sealed.yaml
  - vaultwarden-admin-sealed.yaml
```

---

### immich

```bash
kubectl create secret generic immich-db -n immich \
  --from-literal=password=<cnpg-app-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/immich/immich-db-sealed.yaml
```

Add to `homelab/immich/kustomization.yaml`:
```yaml
  - immich-db-sealed.yaml
```

---

### paperless-ngx

```bash
kubectl create secret generic paperless-db -n paperless \
  --from-literal=password=<cnpg-app-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/paperless-ngx/paperless-db-sealed.yaml

kubectl create secret generic paperless-secret -n paperless \
  --from-literal=secret-key=$(openssl rand -hex 32) \
  --from-literal=admin-password=<choose-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/paperless-ngx/paperless-secret-sealed.yaml
```

Add both to `homelab/paperless-ngx/kustomization.yaml`:
```yaml
  - paperless-db-sealed.yaml
  - paperless-secret-sealed.yaml
```

---

### mealie

> `mealie-oidc` client secret comes from Authentik after creating the OAuth2 provider for Mealie.

```bash
kubectl create secret generic mealie-db -n mealie \
  --from-literal=password=<cnpg-app-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/mealie/mealie-db-sealed.yaml

kubectl create secret generic mealie-oidc -n mealie \
  --from-literal=client_secret=<authentik-client-secret> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/mealie/mealie-oidc-sealed.yaml
```

Add both to `homelab/mealie/kustomization.yaml`:
```yaml
  - mealie-db-sealed.yaml
  - mealie-oidc-sealed.yaml
```

---

### nextcloud

```bash
kubectl create secret generic nextcloud-credentials -n nextcloud \
  --from-literal=username=admin \
  --from-literal=password=<choose-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/nextcloud/nextcloud-credentials-sealed.yaml

kubectl create secret generic nextcloud-db-credentials -n nextcloud \
  --from-literal=db-username=app \
  --from-literal=password=<cnpg-app-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/nextcloud/nextcloud-db-credentials-sealed.yaml
```

Add both to `homelab/nextcloud/kustomization.yaml` (create it if it doesn't exist):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - application.yaml
  - nextcloud-credentials-sealed.yaml
  - nextcloud-db-credentials-sealed.yaml
```

---

### stirling-pdf

```bash
kubectl create secret generic stirling-db-credentials -n stirling-pdf \
  --from-literal=password=<cnpg-app-password> \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
  > homelab/stirling-pdf/stirling-db-credentials-sealed.yaml
```

Add to `homelab/stirling-pdf/kustomization.yaml`:
```yaml
  - stirling-db-credentials-sealed.yaml
```

---

### mediastack

All *arr apps use the `app` postgres user — same password for all.

```bash
for secret in sonarr-db-credentials sonarr-4k-db-credentials radarr-db-credentials radarr-4k-db-credentials prowlarr-db-credentials bazarr-db-credentials; do
  kubectl create secret generic $secret -n media \
    --from-literal=password=<cnpg-app-password> \
    --dry-run=client -o yaml | \
    kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml \
    > homelab/mediastack/${secret}-sealed.yaml
done
```

Add all to `homelab/mediastack/kustomization.yaml`:
```yaml
  - sonarr-db-credentials-sealed.yaml
  - sonarr-4k-db-credentials-sealed.yaml
  - radarr-db-credentials-sealed.yaml
  - radarr-4k-db-credentials-sealed.yaml
  - prowlarr-db-credentials-sealed.yaml
  - bazarr-db-credentials-sealed.yaml
```

---

## 4. Format JuiceFS

After all secrets are applied and the JuiceFS gateway pod is running, the filesystem must be formatted once against the Postgres metadata database. This only needs to be done on a fresh install.

```bash
kubectl exec -n kube-system -it deploy/juicefs-gateway -- juicefs format \
  --storage s3 \
  --bucket "http://garage-s3.garage.svc.cluster.local:3900/juicefs-data" \
  --access-key <garage-key-id> \
  --secret-key <garage-secret> \
  "postgres://app:<cnpg-app-password>@postgres-shared-rw.database.svc.cluster.local/juicefs" \
  juicefs
```
