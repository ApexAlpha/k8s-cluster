# UniFi Network Controller - Host Network Mode

This deploys UniFi Network Controller to your k8s homelab using **host networking** for optimal device discovery and management.

## Architecture

- **UniFi Controller**: Runs on k3s-home node using host network
- **MongoDB 4.4**: Required database, also on k3s-home
- **Storage**: SeaweedFS NVMe replicated storage (20GB UniFi + 10GB MongoDB)
- **Access**: Direct via k3s-home IP on port 8443, or via Traefik at unifi.k8s.hu.ls

## Why Host Network?

Host networking gives the UniFi controller direct access to your LAN, which provides:
- **Automatic L2 device discovery** via UDP broadcasts
- **Simpler networking** - no LoadBalancer needed
- **Better reliability** for device adoption
- **Direct access** to all controller ports

The controller will be accessible at `https://<k3s-home-ip>:8443` and via Traefik at `https://unifi.k8s.hu.ls`.

## Required Ports (automatically available via host network)

- **8443/tcp**: Web UI (HTTPS)
- **8080/tcp**: Device communication
- **3478/udp**: STUN
- **10001/udp**: Device discovery
- **6789/tcp**: Speed test

## Quick Start

### 1. Generate MongoDB Password

```bash
openssl rand -base64 32
```

Update `secrets.yaml` with this password.

### 2. Verify Configuration

Check these settings in the files:

**deployment.yaml**:
- `nodeSelector.kubernetes.io/hostname`: Should match your node name (currently `k3s-home`)
- `env.TZ`: Set your timezone (currently `Europe/Amsterdam`)

**mongodb.yaml**:
- `nodeSelector.kubernetes.io/hostname`: Should match your node name (currently `k3s-home`)

**pvc.yaml & mongodb.yaml**:
- `storageClassName`: Should be `seaweedfs-storage` (NVMe, replicated)

**ingress.yaml**:
- `externalName`: Set to your k3s-home node IP or resolvable hostname

### 3. Deploy

#### Option A: Via ArgoCD (Recommended)

```bash
# Add to your git repo
mkdir -p apps/unifi-controller
cp *.yaml apps/unifi-controller/
git add apps/unifi-controller/
git commit -m "Add UniFi Network Controller"
git push

# Deploy
kubectl apply -f apps/unifi-controller/argocd-application.yaml
```

#### Option B: Manual

```bash
kubectl apply -k .
```

### 4. Monitor Deployment

```bash
# Watch pods
kubectl get pods -n unifi -w

# Check logs
kubectl logs -n unifi deployment/unifi-controller -f
kubectl logs -n unifi deployment/unifi-mongodb -f
```

## Accessing the Controller

### Direct Access
`https://<k3s-home-ip>:8443`

### Via Traefik
`https://unifi.k8s.hu.ls`

**Note**: First access will show a certificate warning (UniFi uses self-signed certs). Accept it to proceed.

## Initial Setup

1. Navigate to the web UI
2. Click "Start" on welcome screen
3. Sign in or create a Ubiquiti account (optional)
4. Configure controller name and settings
5. Controller is ready to adopt devices

## Device Adoption

### Same Network (L2)
Devices on the same LAN as k3s-home should discover automatically.

### Different Network (L3)
SSH into devices and set inform URL:

```bash
ssh ubnt@<device-ip>  # Default password: ubnt
set-inform http://<k3s-home-ip>:8080/inform
```

Or use the Traefik URL:
```bash
set-inform http://unifi.k8s.hu.ls:8080/inform
```

## Troubleshooting

### Pod Won't Start
```bash
kubectl describe pod -n unifi -l app=unifi-controller
kubectl logs -n unifi deployment/unifi-controller
```

### MongoDB Connection Issues
```bash
# Check MongoDB is running
kubectl get pods -n unifi -l app=unifi-mongodb

# Check connectivity from UniFi pod
kubectl exec -it -n unifi deployment/unifi-controller -- sh
nc -zv unifi-mongodb.unifi.svc.cluster.local 27017
```

### Devices Not Adopting
1. Verify controller is accessible from device network
2. Check firewall rules allow required ports
3. Try manual adoption with set-inform
4. Check controller logs for adoption attempts

### Ingress Not Working
```bash
kubectl get ingress -n unifi
kubectl describe ingress -n unifi unifi-controller

# Verify external service resolves correctly
kubectl get svc -n unifi unifi-controller-external
```

Make sure the `externalName` in ingress.yaml points to a resolvable hostname or IP.

## Maintenance

### Backups
Important data is in these PVCs:
- `unifi-data`: Controller configuration and automated backups
- `unifi-mongodb-data`: Database

Set up regular snapshots or backups of these volumes.

### Updates
```bash
# Manual update
kubectl rollout restart deployment/unifi-controller -n unifi
kubectl rollout restart deployment/unifi-mongodb -n unifi

# With ArgoCD, updates happen automatically based on sync policy
```

### Changing Configuration
Edit the manifests in your git repo, commit, and push. ArgoCD will auto-sync.

For manual deployments:
```bash
kubectl apply -k .
```

## Resource Usage

Expected resource consumption:
- **UniFi Controller**: 1-2GB RAM, 0.5-2 CPU cores
- **MongoDB**: 512MB-1GB RAM, 0.25-1 CPU cores
- **Total**: ~2-3GB RAM, ~1-3 CPU cores

Adjust resource limits in deployment.yaml and mongodb.yaml if needed.

## Security Notes

1. **Change MongoDB password** before deploying (in secrets.yaml)
2. **Keep UniFi updated** for security patches
3. **Regular backups** of PVCs
4. **Monitor logs** for unauthorized access attempts
5. Consider using **cert-manager** for proper TLS certificates

## File Structure

```
unifi-controller/
├── namespace.yaml              # Creates unifi namespace
├── secrets.yaml               # MongoDB credentials (CHANGE PASSWORD!)
├── configmap.yaml             # MongoDB initialization
├── pvc.yaml                   # UniFi data volume (20GB)
├── mongodb.yaml               # MongoDB deployment + PVC (10GB)
├── deployment.yaml            # UniFi controller (host network)
├── service.yaml               # MongoDB service
├── ingress.yaml               # Traefik ingress + external service
├── kustomization.yaml         # Kustomize config
├── argocd-application.yaml    # ArgoCD application
└── README.md                  # This file
```

## References

- [LinuxServer.io UniFi Network Application](https://docs.linuxserver.io/images/docker-unifi-network-application)
- [UniFi Network Controller Ports](https://help.ui.com/hc/en-us/articles/218506997)
- [UniFi Documentation](https://help.ui.com/)
