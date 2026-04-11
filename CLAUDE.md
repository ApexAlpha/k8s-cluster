# k8s-cluster

GitOps-managed Kubernetes homelab cluster using ArgoCD.

## Infrastructure

**Domain:** `*.k8s.hu.ls`

**Nodes (flat LAN, both on home network):**
- `k3s-home` — Proxmox VM (192.168.1.228), colocated with bulk storage NAS and gaming Windows VM
- `k3s-nuc` — Intel NUC (192.168.1.230), runs Plex (Intel QuickSync)

## Architecture

- **GitOps:** ArgoCD with automated sync (prune + selfHeal)
- **Ingress:** Traefik exposed via WireGuard tunnel
- **Storage:** Garage (S3-compatible object storage, runs on both nodes as system service) + JuiceFS
- **Database:** CloudNativePG shared PostgreSQL cluster (2 instances, spread across nodes)
- **Secrets:** Kept out of git (`*secret*.yaml` in .gitignore), sealed with kubeseal
- **DNS:** Blocky — two instances, one per node, each with dedicated MetalLB IP (.253 NUC, .254 home)
- **Auth:** Authentik (forwardAuth middleware for all apps via Traefik)

## Directory Structure

```
/bootstrap/       # ArgoCD bootstrap (argo-app.yaml, root-app.yaml)
/homelab/{app}/   # Application manifests (one dir per app)
/argocd-install/  # ArgoCD installation manifests
```

## Sync Wave Order

5: Operators (CNPG, Kured) → 10: Databases → 14-18: Storage (Garage, JuiceFS) → 20+: Apps → 30: Homepage

## Key Applications

- **Media:** Immich, Mediastack (Plex/Sonarr/Radarr/etc), Mealie
- **Documents:** Paperless-NGX, Stirling-PDF
- **Utilities:** Vaultwarden, Nextcloud, IT-Tools, CyberChef
- **Infrastructure:** Traefik, CoreDNS, Blocky, Unifi, Kured
- **Monitoring:** kube-prometheus-stack, Loki, Promtail, Grafana

## MetalLB

Pool: `192.168.1.245-192.168.1.254`
- `.254` — blocky-home (k3s-home)
- `.253` — blocky-nuc (k3s-nuc)

## Garage (S3)

- S3 API in-cluster: `http://garage-s3.garage.svc.cluster.local:3900`
- S3 API external: `https://s3.k8s.hu.ls`
- Admin UI: `https://garage.k8s.hu.ls`
- Barman backups bucket: `s3://postgres-backups/`

## Backups

- **Barman:** nightly at 2 AM to Garage (`s3://postgres-backups/`), 7-day retention
- **rclone:** nightly at 4 AM, syncs all Garage buckets to parents' NAS at `86.82.52.4:22022` (root@) via SFTP. CronJob in `cluster-backup` namespace. NAS path: `/i-data/71a461ba/nfs/NFS_NAS/backup_k3s_cluster_garage`. NAS runs OpenSSH 6.7.

## Known Issues / In Progress

- **k3s embedded registry mirror (Spegel):** `embedded-registry: true` set in `/etc/rancher/k3s/config.yaml` on k3s-home, but k3s-nuc agent crashes on restart when this is added to its config. `journalctl -u k3s-agent` hangs. Needs investigation tomorrow. Goal: fix recurring ImagePullBackOff caused by kubelet doing manifest HEAD checks against registries even when image is cached.
- **Authentik DB lock:** Fixed by adding `conn_max_age: 0` to PostgreSQL config to prevent zombie connections holding advisory locks. Monitor reliability.
- **Plex port 32400:** Added `hostPort: 32400` to expose directly on k3s-nuc's LAN IP (192.168.1.230). Verify it works.

## Commands

```bash
# Apply ArgoCD bootstrap
kubectl apply -f bootstrap/

# Check app sync status
argocd app list

# Check Barman backup status
kubectl cnpg status postgres-shared -n database

# Kill stale Authentik DB connections (if lock issue recurs)
kubectl exec -n database postgres-shared-1 -- psql -U postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='authentik' AND pid <> pg_backend_pid();"

# Trigger manual backup sync test
kubectl create job -n cluster-backup --from=cronjob/garage-to-nas test-backup
kubectl logs -n cluster-backup -l job-name=test-backup -f
```

## Notes

- Renovate handles dependency updates (weekends, automerge for homelab apps)
- Docker images pinned by digest for reproducibility
- Database credentials require manual secret creation
- kubeseal command: `kubeseal --kubeconfig /etc/rancher/k3s/k3s.yaml --format yaml`
- ArgoCD OCI Helm charts from ghcr.io require credentials — credential templates don't work reliably, use `kubectl create secret` with `argocd.argoproj.io/secret-type=repository`
