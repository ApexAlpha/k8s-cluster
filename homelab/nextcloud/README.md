# Nextcloud

Nextcloud deployment using the [community Helm chart](https://github.com/nextcloud/helm) in FPM mode with nginx sidecar.

- **URL**: https://office.k8s.hu.ls
- **Database**: Shared CNPG PostgreSQL cluster (`postgres-shared-rw.database.svc`)
- **File storage**: `local-path` PVC
- **Cache**: Bundled Bitnami Redis (standalone)
- **Ingress**: Traefik with sticky sessions

## Prerequisites

### 1. Create the PostgreSQL database

On an existing cluster, the bootstrap `postInitSQL` won't run. Create the database manually:

```bash
kubectl exec -it postgres-shared-1 -n database -- psql -U app -d app -c "CREATE DATABASE nextcloud OWNER app;"
```

### 2. Create Kubernetes secrets

```bash
# Nextcloud admin credentials
kubectl create namespace nextcloud
kubectl create secret generic nextcloud-credentials -n nextcloud \
  --from-literal=username=admin \
  --from-literal=password='<your-admin-password>'

# PostgreSQL password (same 'app' user password as other services)
kubectl create secret generic nextcloud-db-credentials -n nextcloud \
  --from-literal=password='<your-pg-app-password>'

```

### 3. Update shared PostgreSQL bootstrap (for fresh clusters)

Add to `homelab/cnpg/cluster/postgres-shared.yaml` under `postInitSQL`:

```yaml
- CREATE DATABASE nextcloud OWNER app;
```

## Architecture

```
                    ┌─────────────────────────┐
   Traefik          │     Nextcloud Pod        │
   (sticky) ──────► │  ┌─────────┐ ┌────────┐ │
                    │  │  nginx   │►│  FPM   │ │
                    │  │ :80      │ │ :9000  │ │
                    │  └─────────┘ └────────┘ │
                    │  ┌─────────┐             │
                    │  │  cron   │             │
                    │  │ sidecar │             │
                    │  └─────────┘             │
                    └───────┬─────────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ Postgres │ │ local-path │ │  Redis   │
        │ (shared) │ │ (RWO)    │ │(bundled) │
        └──────────┘ └──────────┘ └──────────┘
```

## Redis: why per-app and not central?

A central Redis _could_ work but adds complexity with no real benefit at homelab scale:

- Each app already runs its own Redis (Paperless, Immich)
- Bitnami Redis in standalone mode uses ~64MB RAM
- Per-app isolation means one app's cache flush doesn't affect others
- No need to manage database numbers or key prefixes across apps

## Useful commands

```bash
# Run occ commands
kubectl exec -n nextcloud deploy/nextcloud -- su -s /bin/sh www-data -c "php occ status"

# Add missing database indices after upgrade
kubectl exec -n nextcloud deploy/nextcloud -- su -s /bin/sh www-data -c "php occ db:add-missing-indices"

# Maintenance mode
kubectl exec -n nextcloud deploy/nextcloud -- su -s /bin/sh www-data -c "php occ maintenance:mode --on"
kubectl exec -n nextcloud deploy/nextcloud -- su -s /bin/sh www-data -c "php occ maintenance:mode --off"

# Scan files (if you ever add files outside Nextcloud)
kubectl exec -n nextcloud deploy/nextcloud -- su -s /bin/sh www-data -c "php occ files:scan --all"
```
