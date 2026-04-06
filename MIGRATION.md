# Cluster Migration Guide

Migration from 3-node WAN cluster (home + NUC + Hetzner) to 2-node LAN cluster (home VM + NUC bare metal).

## Target Architecture

| Node | Role | RAM | Storage |
|------|------|-----|---------|
| Home VM (Proxmox) | k3s control plane + worker | 12GB | 2TB NVMe (Garage) |
| NUC (bare metal) | k3s worker | 16GB | 2TB NVMe (Garage) |

- **CNI:** Flannel (k3s default)
- **LoadBalancer:** MetalLB (L2, pool 192.168.1.245-254)
- **DNS/VPN:** WireGuard (replacing Netbird), wg-easy on Proxmox host
- **Storage:** Garage replication factor 1 (4TB usable), JuiceFS on top
- **Database:** CNPG single instance PG18, pinned to home VM, local-path storage
- **Kured:** Removed — replaced by unattended-upgrades + Canonical Livepatch
- **Backups:** rclone to Raspberry Pi + NAS at parents via WireGuard, or S3

---

## Phase 1 — Prepare Current Cluster

### 1. Export all secrets
```bash
kubectl get secrets -A -o yaml > ~/secrets-backup.yaml
```
Keep this file safe — it is not in git.

### 2. Move CNPG primary to home node
Check where primary is currently running:
```bash
kubectl get pods -n database -o wide
```
If primary is on Hetzner or NUC, trigger a switchover:
```bash
kubectl annotate cluster postgres-shared -n database \
  cnpg.io/switchoverTarget=<home-pod-name> --overwrite
```
Wait until the home node pod shows as primary before continuing.

### 3. Rebalance Garage to home node only
```bash
garage layout assign <home-node-id> -z home -c 2000GB
garage layout remove <hetzner-node-id>
garage layout remove <nuc-node-id>
garage layout show   # verify
garage layout apply --version <version>
garage stats         # wait for rebalance to complete
```
Do not proceed until all data is on the home node.

### 4. Remove Kured from git
Delete `homelab/kured/` directory and remove it from `homelab/kustomization.yaml`. Commit and let ArgoCD sync.

---

## Phase 2 — Remove Hetzner and NUC from Cluster

```bash
# Drain and delete Hetzner
kubectl drain k3s-hetzner --ignore-daemonsets --delete-emptydir-data
kubectl delete node k3s-hetzner

# Drain and delete NUC
kubectl drain k3s-nuc --ignore-daemonsets --delete-emptydir-data
kubectl delete node k3s-nuc
```

Verify all workloads are running on the home node:
```bash
kubectl get pods -A -o wide
```

---

## Phase 3 — Rebuild Home Node with Cilium

### 1. Prep: check NIC name on home VM
NIC names are already configured in `homelab/cilium/l2-announcement.yaml`:
- Home VM: `ens18`
- NUC: `enp89s0`

### 2. Prep: Garage IP
Home VM LAN IP `192.168.1.228` already set in `homelab/garage/services.yaml`.

### 3. Uninstall k3s on home VM
```bash
/usr/local/bin/k3s-uninstall.sh
```

### 4. Reinstall k3s (flannel + kube-proxy, no traefik)
```bash
curl -sfL https://get.k3s.io | sh -s - \
  --disable=traefik
```

### 5. Re-apply secrets
```bash
kubectl apply -f ~/secrets-backup.yaml
```

### 6. Bootstrap ArgoCD
```bash
kubectl apply -f bootstrap/
```
ArgoCD will sync everything from git. MetalLB (wave 4-5) will come up before apps and assign LoadBalancer IPs from the pool.
Monitor progress:
```bash
argocd app list
```

### 7. Update CoreDNS after Traefik gets its IP
Once Traefik has a LoadBalancer IP from the MetalLB pool:
```bash
kubectl get svc -n kube-system traefik
```
Update `homelab/coredns/coredns-custom.yaml` with that IP and commit.

---

## Phase 4 — Update Manifests

These changes should be committed to git before or during the migration:

### CNPG cluster (`homelab/cnpg/cluster/postgres-shared.yaml`)
- `instances: 1` (single node, no replica)
- Switch image to `ghcr.io/cloudnative-pg/postgresql:18` (standard image includes pgvector)
- Remove `podAntiAffinity` (no zones on single node)
- Remove WAN tuning (wal_sender_timeout, tcp_keepalives, wal_keep_size)
- Remove Netbird VPN range from `pg_hba`
- Remove `vchord.so` from `shared_preload_libraries`
- Remove `vchord` extension from `postInitTemplateSQL`
- Add `nodeSelector` to pin to home VM node

### Garage (`homelab/garage/`)
- Remove Netbird IPs from `services.yaml`, use cluster-internal IPs
- Update to 2-node layout

### Netbird
- Delete `homelab/netbird-operator.yaml`
- Delete `homelab/coredns/coredns-netbird-svc.yaml`
- Remove from `homelab/kustomization.yaml`

### Node affinity cleanup
Remove or relax `podAffinity` rules that pin to CNPG primary node across:
- `homelab/audiobookshelf/deployment.yaml` (required → remove)
- `homelab/mediastack/` (sonarr, sonarr-4k, radarr, radarr-4k, prowlarr, bazarr)
- `homelab/paperless-ngx/deployment.yaml`
- `homelab/mealie/deployment.yaml`
- `homelab/immich/server.yaml`
- `homelab/nextcloud/application.yaml`

Since CNPG is single instance on home VM, these affinities are no longer meaningful.

### Pin Immich ML and Plex to NUC
Add `nodeSelector` for the NUC node to use Intel QuickSync iGPU:
- `homelab/immich/` — ML container
- `homelab/mediastack/` — Plex/Jellyfin transcoding

---

## Phase 5 — Add NUC as Worker

### 1. Install Ubuntu 24.04 on NUC (bare metal)
```bash
apt install linux-generic-hwe-24.04
apt install unattended-upgrades
# Enable Canonical Livepatch
canonical-livepatch enable <token>
```

### 2. Join NUC to cluster
Get join token from home node:
```bash
cat /var/lib/rancher/k3s/server/node-token
```
On NUC:
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<home-vm-ip>:6443 \
  K3S_TOKEN=<token> sh -
```

### 3. Expand Garage to NUC
```bash
garage layout assign <nuc-node-id> -z nuc -c 2000GB
garage layout show
garage layout apply --version <version>
```

---

## Phase 6 — Networking

### Headscale (already done)
- Running on Proxmox host at `vpn.hu.ls:8443`
- Install Tailscale client on all devices and connect to Headscale

### Home VM as subnet router
Add the home VM to Headscale and advertise the LAN subnet so remote clients can reach Traefik:
```bash
tailscale up --login-server https://vpn.hu.ls:8443 --advertise-routes=192.168.1.0/24
```
Approve the route on Proxmox host:
```bash
headscale routes list
headscale routes enable -r <route-id>
```
Remote Tailscale clients can now reach `192.168.1.245` (Traefik) and any other LAN IP.

### MetalLB + Blocky for DNS
- MetalLB L2 pool: `192.168.1.245-254` (already in repo at `homelab/metallb/`)
- Blocky has a LoadBalancer service — MetalLB assigns it a LAN IP on port 53
- Set that IP as DNS server in UniFi DHCP settings
- LAN clients get ad blocking and `*.k8s.hu.ls` resolution without VPN

### Traefik via MetalLB
- Traefik service type is already `LoadBalancer` — MetalLB assigns it a LAN IP
- Port forward 443 on router to that IP for external access
- Update `homelab/coredns/coredns-custom.yaml` with the assigned IP

### Raspberry Pi at parents (backup gateway)
- Install Tailscale on Pi, connect to Headscale
- Mount NAS via NFS locally on Pi
- rclone from cluster to NAS over the Tailscale tunnel

---

## Phase 7 — Cancel Hetzner

Once cluster is healthy, NUC is joined, and backups are configured:
- Cancel Hetzner dedicated server (~€50/month saving)

---

## Post-Migration Checklist

- [ ] All apps healthy in ArgoCD
- [ ] CNPG on PG18, single instance, home VM
- [ ] Garage replication factor 1, both nodes, 4TB usable
- [ ] JuiceFS connected to local Garage on each node
- [ ] Headscale running on Proxmox host (already done)
- [ ] Home VM joined to Headscale as subnet router (192.168.1.0/24 advertised)
- [ ] MetalLB pool active (192.168.1.245-254)
- [ ] Blocky on MetalLB IP, set as LAN DNS in UniFi
- [ ] Traefik on MetalLB IP, port 443 forwarded from router
- [ ] CoreDNS coredns-custom.yaml updated with Traefik LAN IP
- [ ] Immich ML pinned to NUC (Intel iGPU)
- [ ] Plex transcoding pinned to NUC (QuickSync)
- [ ] Unattended upgrades + Livepatch on both nodes
- [ ] rclone backup to parents NAS configured
- [ ] Hetzner cancelled
- [ ] Shelly plug monitoring home server power draw
