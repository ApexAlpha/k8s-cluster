# Vaultwarden + Envoy Gateway

## Manual Steps (Before Push)

### 1. Create Cloudflare API Token

1. Cloudflare Dashboard → My Profile → API Tokens → Create Token
2. Template: "Edit zone DNS" or custom with:
   - **Permissions:** Zone → DNS → Edit
   - **Zone Resources:** Include → Specific zone → hu.ls
3. Create the secret:

```bash
kubectl create secret generic cloudflare-api-token \
  --namespace cert-manager \
  --from-literal=api-token="YOUR_CLOUDFLARE_TOKEN"
```

### 2. Create PostgreSQL Database

```bash
kubectl exec -it <cnpg-cluster>-1 -n <cnpg-namespace> -- psql -U postgres
```

```sql
CREATE DATABASE vaultwarden;
CREATE USER vaultwarden WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;
\c vaultwarden
GRANT ALL ON SCHEMA public TO vaultwarden;
\q
```

### 3. Create Vaultwarden DB Secret

```bash
kubectl create namespace vaultwarden

kubectl create secret generic vaultwarden-db \
  --namespace vaultwarden \
  --from-literal=DATABASE_URL="postgresql://vaultwarden:YOUR_PASSWORD@CNPG_CLUSTER-rw.CNPG_NAMESPACE.svc:5432/vaultwarden"
```

### 4. Update Email in cluster-issuer.yaml

Change `admin@hu.ls` to your email address.

---

## Deploy Order

**Step 1: Deploy Envoy Gateway first**

```bash
kubectl apply -f homelab/envoy-gateway/application.yaml
```

Wait for it to be ready:
```bash
kubectl wait --timeout=5m --for=condition=Accepted gatewayclass/eg
```

**Step 2: Deploy Vaultwarden**

Push to git or:
```bash
kubectl apply -f homelab/vaultwarden/application.yaml
```

---

## Sync Waves

| Wave | Resource |
|------|----------|
| 0 | vaultwarden namespace |
| 1 | ClusterIssuer |
| 2 | Wildcard Certificate |
| 3 | Gateway |
| 4 | PVC, Deployment, Service |
| 5 | HTTPRoutes |

---

## Post-Deploy

### Get Gateway IP for Netbird

```bash
kubectl get gateway -n envoy-gateway-system main-gateway -o jsonpath='{.status.addresses[0].value}'
```

Configure Netbird DNS: `*.k8s.hu.ls` → Gateway IP

### Verify Certificate

```bash
kubectl get certificate -n envoy-gateway-system
```

### Access

```
https://vault.k8s.hu.ls
```

---

## First Account Setup

1. Temporarily set `SIGNUPS_ALLOWED: "true"` in deployment.yaml
2. Push / sync
3. Create your account
4. Set `SIGNUPS_ALLOWED: "false"` and sync again
