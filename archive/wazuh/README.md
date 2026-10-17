# Wazuh 4.14.8 (single-node eval)

SIEM/XDR stack on k3s, managed by ArgoCD. Deployed for evaluation, not production.

- Dashboard: <https://wazuh.k8s.hu.ls> (Traefik `websecure` + wildcard TLS + Authentik forwardAuth)
- Upstream source: [`wazuh/wazuh-kubernetes` tag `v4.14.8`](https://github.com/wazuh/wazuh-kubernetes/tree/v4.14.8)
- Images: `wazuh/wazuh-indexer:4.14.8`, `wazuh/wazuh-manager:4.14.8`, `wazuh/wazuh-dashboard:4.14.8` (Docker Hub, anonymous pulls)

Wazuh publishes no first-party Helm chart; the manifests here are that repo's
kustomize set, vendored and adapted (diff is small and intentional — see below).

## Why 4.14.8 and not 5.x

The `master` branch of the upstream repo targets `5.1.0` images that are **not
published on Docker Hub** (HTTP 404 — verified). The newest published 5.x line is
`5.0.0-beta5` (`VERSION.json` → `stage: beta5`). 4.14.8 is the current stable
release (23 September 2026, per the upstream release notes).

## Layout

| File | Purpose |
| --- | --- |
| `application.yaml` | ArgoCD child Application (wave 25) |
| `kustomization.yaml` | resources + `configMapGenerator` for the three conf sets |
| `namespace.yaml` | namespace with PSA `enforce=baseline` / `audit=restricted` |
| `indexer-sts.yaml` | Wazuh indexer (OpenSearch fork), 1 replica, 8 Gi PVC |
| `wazuh-master-sts.yaml` | manager master (authd + API), 2 Gi PVC |
| `wazuh-worker-sts.yaml` | manager worker (agent events), 2 Gi PVC |
| `dashboard-deploy.yaml` | Wazuh dashboard (own TLS on 5601) |
| `*-svc.yaml` | ClusterIP/headless services |
| `servers-transport.yaml` | Traefik → dashboard TLS verification |
| `ingressroute.yaml` | public route behind Authentik |
| `conf/` | `opensearch.yml`, `internal_users.yml`, `master.conf`, `worker.conf`, `opensearch_dashboards.yml` |
| `sealed/` | SealedSecrets: 5 credential sets + 3 certificate bundles + Traefik CA |

## Deviations from upstream (all deliberate)

1. **Services → `ClusterIP`.** Upstream ships `type: LoadBalancer` with AWS
   annotations; MetalLB would consume three more addresses from the `.245–.254`
   pool for no benefit.
2. **Dropped the privileged `increase-the-vm-max-map-count` init container.** It
   runs `sysctl -w vm.max_map_count=262144` with `privileged: true`, which PSA
   `baseline` rejects. All three nodes already report `vm.max_map_count=1048576`.
3. **`wazuh-storage` StorageClass removed** (upstream ships it with no
   provisioner); PVCs use `local-path`. Sizes raised from 500 Mi to 8 Gi
   (indexer) / 2 Gi (each manager) for an eval that will actually ingest.
4. **Pinned to `k3s-home-2`** via `nodeSelector` — the only node with both RAM
   headroom (~8 Gi free) and acceptable request headroom.
5. **Explicit requests + limits** on every container (upstream sets limits only,
   which makes the effective request equal to the limit and would not fit).
   Total requests ≈ 550 m CPU / 2.7 Gi RAM.
6. **Ingress replaced.** Upstream's 4.14.8 layout exposes the dashboard via a
   `LoadBalancer` with its own certs. Here Traefik terminates the browser side
   (`websecure`, wildcard cert, Authentik + maintenance middlewares) and
   re-encrypts to the dashboard over HTTPS using a `ServersTransport` that
   validates the chain against the Wazuh root CA (no verification skipped).
   The dashboard certificate therefore carries `SAN DNS:dashboard`, and all
   certs are generated with the upstream `generate_certs.sh` logic.
7. **`opensearch.ssl.verificationMode: none` → `certificate`** in
   `opensearch_dashboards.yml`, so the dashboard validates the indexer's chain.
8. **No upstream IngressRoute/LoadBalancer/Traefik runtime manifests** are
   vendored — the cluster's own Traefik (Helm, v3.7.13) is used.
9. **`secretGenerator` replaced by SealedSecrets.** Upstream generates secrets
   from a local `config/` tree, which would put certificates in git.
10. **Credentials rotated.** No upstream default (`admin/SecretPassword`,
    `kibanaserver/kibanaserver`, `wazuh-wui/…`, authd `password`, the public
    cluster key) is used. Passwords are random and live only in SealedSecrets;
    `conf/internal_users.yml` holds matching `$2y$12$` bcrypt hashes produced
    with `htpasswd -bnBC 12` (the same method as Wazuh's `hash.sh`). The
    upstream demo accounts (`kibanaro`, `logstash`, `readall`,
    `snapshotrestore`) are retained but given unrecorded random passwords, so
    they cannot be logged into.

## Known gaps / follow-ups

- **No Wazuh agents enrolled yet.** A node-level agent DaemonSet needs
  `hostPath` mounts for `/var/log`, `/etc`, `/proc`, which PSA `baseline`
  forbids. Options: label this namespace `privileged` (weakens the whole
  stack), or run agents without host filesystem access (less useful), or run
  the agents outside the cluster. Undecided.
- Single indexer replica: no redundancy, and `local-path` storage is
  node-bound, so the indexer cannot move off `k3s-home-2` without a data
  migration.
- Certificates are valid for 3650 days and are not auto-rotated (cert-manager
  is not wired into the Wazuh CA).
- Indexer/manager/dashboard are unversioned beyond the pinned image tags;
  upstream 4.14.x patch releases need a manual tag bump.

## Operations

```bash
kubectl -n wazuh get pods,pvc
kubectl -n wazuh logs sts/wazuh-indexer
# Wazuh API / indexer reachability from inside the cluster
kubectl -n wazuh exec -it sts/wazuh-manager-master -- /var/ossec/bin/wazuh-control status
```

Credentials are in the SealedSecrets under `sealed/`; to read a value, decode
the corresponding Secret in-cluster (`kubectl -n wazuh get secret indexer-cred
-o jsonpath='{.data.password}' | base64 -d`).
