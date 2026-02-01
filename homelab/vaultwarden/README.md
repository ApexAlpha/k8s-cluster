# Vaultwarden Setup

## Prerequisites

### 1. Create the PostgreSQL database

Connect to your CNPG cluster:
```bash
kubectl exec -it <cnpg-cluster>-1 -n <cnpg-namespace> -- psql -U postgres
```

Create the database and user:
```sql
CREATE DATABASE vaultwarden;
CREATE USER vaultwarden WITH PASSWORD 'your-secure-password-here';
GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;
\c vaultwarden
GRANT ALL ON SCHEMA public TO vaultwarden;
```

### 2. Create the secret manually (not in Git)

```bash
kubectl create namespace vaultwarden

kubectl create secret generic vaultwarden-db \
  --namespace vaultwarden \
  --from-literal=DATABASE_URL="postgresql://vaultwarden:your-secure-password-here@<cnpg-cluster>-rw.<cnpg-namespace>.svc:5432/vaultwarden"
```

### 3. (Optional) Create admin token secret

Generate a secure token:
```bash
openssl rand -base64 48
```

Create the secret:
```bash
kubectl create secret generic vaultwarden-admin \
  --namespace vaultwarden \
  --from-literal=ADMIN_TOKEN="your-generated-token"
```

Then uncomment the ADMIN_TOKEN env var in deployment.yaml.

## Deploy

```bash
kubectl apply -k .
```

## Configuration

Update these values in `deployment.yaml`:
- `DOMAIN`: Your Vaultwarden URL (e.g., https://vault.yourdomain.com)
- `SIGNUPS_ALLOWED`: Set to "true" initially to create your first account, then disable

## Verify

```bash
kubectl get pods -n vaultwarden
kubectl logs -n vaultwarden -l app=vaultwarden
```

## Access

The service is exposed on ClusterIP. Configure your Netbird/ingress to route to:
- `vaultwarden.vaultwarden.svc:80` (HTTP)
- `vaultwarden.vaultwarden.svc:3012` (WebSocket)
