# Paperless-ngx

Document management system with OCR and full-text search.

## Access

- **URL**: https://docs.k8s.hu.ls (via Netbird)

## Prerequisites

Before deploying, you need to:

### 1. Create the database (if cluster already exists)

Since CNPG's `postInitSQL` only runs on initial bootstrap, if your cluster already exists you need to manually create the database:

```bash
# Get the postgres password
kubectl get secret postgres-shared-app -n database -o jsonpath='{.data.password}' | base64 -d

# Connect to postgres
kubectl exec -it postgres-shared-1 -n database -- psql -U app

# Create the database
CREATE DATABASE paperless OWNER app;
\q
```

### 2. Create secrets

```bash
# Database password (same as CNPG app user)
PGPASS=$(kubectl get secret postgres-shared-app -n database -o jsonpath='{.data.password}' | base64 -d)

kubectl create secret generic paperless-db \
  --namespace paperless \
  --from-literal=password="$PGPASS"

# Paperless secrets
kubectl create secret generic paperless-secret \
  --namespace paperless \
  --from-literal=secret-key="$(openssl rand -base64 48)" \
  --from-literal=admin-password="$(openssl rand -base64 16)"
```

**Save the admin password!** You'll need it to log in:
```bash
kubectl get secret paperless-secret -n paperless -o jsonpath='{.data.admin-password}' | base64 -d
```

### 3. Ensure namespace exists first

```bash
kubectl create namespace paperless
```

Then create secrets, then let ArgoCD sync the rest.

## Configuration

### OCR Languages

Edit `deployment.yaml` to change OCR languages:
```yaml
- name: PAPERLESS_OCR_LANGUAGE
  value: "eng+deu+fra"  # English + German + French
```

Available language codes: https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html

### Timezone

```yaml
- name: PAPERLESS_TIME_ZONE
  value: "Europe/Amsterdam"
```

### Office Document Support (Optional)

To process Word, Excel, PowerPoint files, uncomment the Tika/Gotenberg configuration in `deployment.yaml` and deploy those services separately.

## Usage

### Consuming Documents

Documents placed in the consume folder are automatically imported. You can:

1. **Upload via web UI**: Just drag and drop
2. **Use the consume folder**: Copy files to the PVC
3. **Email**: Configure email polling (see Paperless docs)
4. **API**: POST to `/api/documents/post_document/`

### Storage

| PVC | Purpose | Size |
|-----|---------|------|
| paperless-data | Database, search index, thumbnails | 10Gi |
| paperless-media | Original & archived documents | 50Gi |
| paperless-export | Bulk exports | 10Gi |
| paperless-consume | Auto-import watch folder | 5Gi |

All storage uses SeaweedFS CSI for geo-distributed replication.

## Troubleshooting

### Check logs
```bash
kubectl logs -f deployment/paperless -n paperless
```

### Database connection issues
```bash
# Verify postgres is accessible
kubectl exec -it deployment/paperless -n paperless -- \
  python3 -c "import psycopg2; psycopg2.connect('host=postgres-shared-rw.database.svc dbname=paperless user=app password=xxx')"
```

### Redis issues
```bash
kubectl logs -f deployment/paperless-redis -n paperless
```
