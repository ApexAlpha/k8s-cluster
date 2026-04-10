# k8s-cluster

GitOps-managed Kubernetes homelab cluster using ArgoCD.

## Infrastructure

**Domain:** `*.k8s.hu.ls`

**Nodes (flat LAN, both on home network):**
- Proxmox VM (colocated with bulk storage NAS and gaming Windows VM)
- Intel NUC

## Architecture

- **GitOps:** ArgoCD with automated sync (prune + selfHeal)
- **Ingress:** Traefik exposed via WireGuard tunnel
- **Storage:** Garage (S3-compatible object storage) + JuiceFS
- **Database:** CloudNativePG shared PostgreSQL cluster
- **Secrets:** Kept out of git (`*secret*.yaml` in .gitignore)

## Directory Structure

```
/bootstrap/       # ArgoCD bootstrap (argo-app.yaml, root-app.yaml)
/homelab/{app}/   # Application manifests (one dir per app)
/argocd-install/  # ArgoCD installation manifests
```

## Sync Wave Order

5: Operators (CNPG, Kured) → 10: Databases → 14-18: Storage (Garage, JuiceFS) → 20+: Apps → 30: Homepage

## Key Applications

- **Media:** Immich, Mediastack, Mealie
- **Documents:** Paperless-NGX, Stirling-PDF
- **Utilities:** Vaultwarden, Nextcloud, IT-Tools, CyberChef
- **Infrastructure:** Traefik, CoreDNS, Unifi, Kured

## Commands

```bash
# Apply ArgoCD bootstrap
kubectl apply -f bootstrap/

# Check app sync status
argocd app list
```

## Notes

- Renovate handles dependency updates (weekends, automerge for homelab apps)
- Docker images pinned by digest for reproducibility
- Database credentials require manual secret creation
