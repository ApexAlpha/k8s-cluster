# NeuVector (SUSE Security) — evaluation deployment

Chart `neuvector/core` **2.11.2** (appVersion **5.6.2**) from
`https://neuvector.github.io/neuvector-helm`, deployed by the `neuvector`
ArgoCD Application in this directory.

This is an **evaluation** install, not a hardened production one:

- **1 controller** (with a local-path PVC), **1 manager** (the UI), **1 scanner**,
  and an **enforcer DaemonSet on all three nodes**.
- Namespace `neuvector` is labelled `pod-security.kubernetes.io/enforce=privileged`.
  The enforcer mounts host paths and the containerd socket; it cannot run under
  baseline. Same trade-off already accepted for Falco and Home Assistant.
- UI at **https://neuvector.k8s.hu.ls**, gated by Traefik + the shared
  `authentik-authentik` forwardAuth middleware. Traefik reaches the manager over
  HTTPS using the ServersTransport the chart generates
  (`ingressController: traefik`).

## Traps this deployment had to work around

1. **`autoGenerateCert` must stay `false`.** `controller-secret.yaml` and
   `manager-secret.yaml` call `genSelfSignedCert` on every render, and the
   controller/manager pod templates carry `checksum/<secret>` annotations of that
   file. ArgoCD re-renders on every sync, so the hash changes, a new ReplicaSet
   appears and the Deployments roll on every sync — with `selfHeal: true` that
   never settles. The certs are supplied as SealedSecrets instead
   (`neuvector-controller-secret`, `neuvector-manager-secret`, keys `tls.pem` /
   `tls.key`, 10-year RSA, CN + SAN `neuvector`).
2. **The internal CA ships expired.** `neuvector-internal-certs` is created empty
   and gets seeded with NeuVector's 2016 default CA (valid until 2026-05-17).
   The `cert-upgrader` job then generates `new-ca.crt` / `new-tls.crt` /
   `new-tls.key` and waits for `neuvector-controller-pod` to finish rolling —
   while the controller waits for valid internal certs, i.e. a deadlock. Fix:
   promote the upgrader's own new certs into the primary keys
   (`ca.crt` / `tls.crt` / `tls.key`) and restart the controller and manager.
   Do this *after* the churn fix above, otherwise the rollout never completes.
3. **The manager needs more than the chart's 512Mi.** It is a JVM (Pekko) app and
   is OOMKilled ~20s after start, right after "Import manager's certificate and
   private key to manager's keystore". It runs with a 2Gi limit here.
4. **`runtimePath`** must be `/run/k3s/containerd/containerd.sock`; the chart
   otherwise probes the default containerd socket, which k3s does not use.
5. **NetworkPolicies** (`homelab/netpols/04-baseline.yaml`) are the usual
   default-deny + intra-namespace + traefik + monitoring, plus
   `allow-apiserver-webhooks`. The API server is a host process on each k3s node,
   so its calls to the controller's admission (20443) and CRD (30443) webhooks
   carry no pod identity and cannot be matched with a namespaceSelector. The rule
   lists the three node IPs explicitly — **update it when a node is added**.
   Without it, enabling NeuVector admission control fails closed.
6. **Capacity:** `k3s-nuc` sits at ~95% of memory *requests*; the enforcer there
   adds 256Mi. It fits, but nuc is the node to watch.

## Operating notes

- Controller state (admin user, policy, CVE DB) lives on the `local-path` PVC, so
  it survives a pod restart. Deleting the PVC resets the install to defaults.
- `controller.replicas: 1` means no controller HA — fine for an eval, but the
  manager UI is unavailable while that single controller restarts.
- The enforcer is a DaemonSet with a privileged container; expect it in host
  network/process views (`kubectl -n neuvector get pods -l app=neuvector-enforcer-pod`).
