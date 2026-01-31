# Homelab Kubernetes GitOps

This repository contains the complete GitOps configuration for a 3-node K3s cluster.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    3-Node HA Cluster                             │
│                                                                  │
│   k3s-home (Proxmox)    k3s-nuc (NUC)      k3s-hetzner (VPS)   │
│   ┌───────────┐         ┌───────────┐      ┌───────────┐        │
│   │ K3s Server│         │ K3s Server│      │ K3s Server│        │
│   │ + etcd    │◄───────►│ + etcd    │◄────►│ + etcd    │        │
│   │ + worker  │         │ + worker  │      │ + worker  │        │
│   └───────────┘         └───────────┘      └───────────┘        │
│                                                                  │
│   Storage: NVMe + HDD    Storage: NVMe     Storage: VPS disk    │
│            iSCSI NAS                + iSCSI                      │
└─────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
.
├── apps/                    # Application definitions
│   ├── argocd/             # ArgoCD (self-managed)
│   ├── cert-manager/       # TLS certificate management
│   ├── netbird-operator/   # Netbird K8s operator
│   ├── seaweedfs/          # Distributed storage
│   ├── cnpg/               # CloudNativePG operator
│   └── ...                 # Other apps
├── infrastructure/          # Cluster infrastructure
│   ├── namespaces/         # Namespace definitions
│   └── storage-classes/    # Storage class definitions
└── clusters/
    └── homelab/
        ├── apps.yaml       # Root app-of-apps
        └── infrastructure.yaml
```

## Sync Waves

| Wave | Components |
|------|------------|
| -3   | Namespaces, CRDs |
| -2   | cert-manager |
| -1   | Netbird operator, ArgoCD config |
| 0    | SeaweedFS, Ingress |
| 1    | CNPG operator |
| 2    | Databases |
| 3    | Applications |

## Quick Start

```bash
# 1. Fork/clone this repo

# 2. Update YOUR_USERNAME in all files
find . -type f -name "*.yaml" -exec sed -i 's/YOUR_USERNAME/yourusername/g' {} \;

# 3. Create required secrets
kubectl create namespace netbird
kubectl -n netbird create secret generic netbird-mgmt-api-key \
  --from-literal=NB_API_KEY='your-token'

# 4. Bootstrap ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5. Apply root application
kubectl apply -f clusters/homelab/apps.yaml
```

## Access

- ArgoCD: https://argocd.netbird.cloud (via Netbird)
- Domain: hu.ls

## Components

### Infrastructure
- **K3s**: Lightweight Kubernetes distribution
- **etcd**: Distributed key-value store (embedded in K3s)
- **Netbird**: WireGuard-based mesh VPN

### Storage
- **SeaweedFS**: Distributed storage with tiering (NVMe → HDD)

### Database
- **CNPG**: CloudNativePG for PostgreSQL management

### Applications
- Vaultwarden
- *arr stack (Radarr, Sonarr, etc.)
- Plex
- And more...
