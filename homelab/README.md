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
│   ├── sealed-secrets/     # Secrets encryption
│   ├── netbird-operator/   # Netbird K8s operator
│   ├── seaweedfs/          # Distributed storage
│   ├── cnpg-operator/      # CloudNativePG operator
│   ├── cnpg-cluster/       # PostgreSQL cluster
│   └── vaultwarden/        # Example app
├── infrastructure/          # Cluster infrastructure
│   └── namespaces/         # Namespace definitions
├── clusters/
│   └── homelab/
│       └── apps.yaml       # Root app-of-apps
└── scripts/
    ├── bootstrap.sh        # Initial cluster setup
    └── seal-secret.sh      # Secrets helper
```

## Sync Waves

| Wave | Components |
|------|------------|
| -3   | Namespaces, CRDs |
| -2   | cert-manager, sealed-secrets |
| -1   | Netbird operator, ArgoCD config |
| 0    | Netbird config, SeaweedFS |
| 1    | CNPG operator |
| 2    | CNPG cluster (databases) |
| 3    | Applications |

## Quick Start

```bash
# 1. Fork/clone this repo
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab

# 2. Update YOUR_USERNAME in all files
find . -type f -name "*.yaml" -exec sed -i 's/YOUR_USERNAME/yourusername/g' {} \;

# 3. Bootstrap the cluster
./scripts/bootstrap.sh

# 4. Wait for sealed-secrets to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets -n kube-system --timeout=300s

# 5. Create your sealed secrets
./scripts/seal-secret.sh

# 6. Commit and push sealed secrets
git add -A
git commit -m "Add sealed secrets"
git push
```

## Secrets Management

This repo uses **Sealed Secrets** for GitOps-compatible secret management.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│   1. You create a plain secret (locally, never committed)       │
│   2. kubeseal encrypts it with cluster's public key             │
│   3. Encrypted SealedSecret is safe to commit to Git            │
│   4. Sealed Secrets controller decrypts it in-cluster           │
└─────────────────────────────────────────────────────────────────┘
```

### Creating Secrets

Use the helper script:

```bash
./scripts/seal-secret.sh
```

Or manually:

```bash
# Create plain secret (don't commit!)
cat > /tmp/my-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-namespace
type: Opaque
stringData:
  key: "value"
EOF

# Seal it
kubeseal --controller-name=sealed-secrets-controller \
         --controller-namespace=kube-system \
         --format yaml \
         < /tmp/my-secret.yaml \
         > apps/my-app/manifests/sealed-secret.yaml

# Delete plain secret
rm /tmp/my-secret.yaml

# Commit sealed secret
git add apps/my-app/manifests/sealed-secret.yaml
git commit -m "Add my-app secret"
git push
```

### Required Secrets

| Secret | Namespace | Purpose |
|--------|-----------|---------|
| `netbird-mgmt-api-key` | netbird | Netbird API access |
| `seaweedfs-s3-creds` | databases | CNPG backup storage |
| `vaultwarden-db-credentials` | apps | Database connection |
| `vaultwarden-admin` | apps | Admin panel access |

## Access

- ArgoCD: https://argocd.netbird.cloud (via Netbird)
- Domain: hu.ls

## Components

### Infrastructure
- **K3s**: Lightweight Kubernetes distribution
- **etcd**: Distributed key-value store (embedded in K3s)
- **Netbird**: WireGuard-based mesh VPN
- **Sealed Secrets**: GitOps-compatible secrets

### Storage
- **SeaweedFS**: Distributed storage with tiering (NVMe → HDD)

### Database
- **CNPG**: CloudNativePG for PostgreSQL management (3-way async replication)

### Applications
- Vaultwarden
- *arr stack (Radarr, Sonarr, etc.)
- Plex
- And more...

## Troubleshooting

### Check ArgoCD sync status
```bash
kubectl get applications -n argocd
```

### View application logs
```bash
argocd app logs <app-name>
```

### Reseal a secret (if cluster was rebuilt)
```bash
# Get new public key
kubeseal --fetch-cert > /tmp/sealed-secrets.pem

# Reseal all secrets using ./scripts/seal-secret.sh
```

### Force sync an application
```bash
argocd app sync <app-name> --force
```
