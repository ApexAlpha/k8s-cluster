# system-upgrade (k3s Automated Upgrades)

Installs Rancher's [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller)
+ two `Plan` CRs that keep the k3s cluster on the **stable** release channel.

Upgrades run in a **nightly window (06:30–08:00 UTC)** — after all backups
(CNPG base 02:00, velero 03:00, garage→Hetzner 04:00) and the 05:00 morning
status report.

## Layout

| File | Purpose |
|------|---------|
| `crd.yaml` | `plans.upgrade.cattle.io` CRD (vendored from Rancher releases) |
| `controller.yaml` | system-upgrade-controller Deployment + RBAC (vendored) |
| `server-plan.yaml` | Upgrades the control-plane node (k3s-home) |
| `agent-plan.yaml` | Upgrades worker node(s) (k3s-nuc), waits for server-plan |
| `application.yaml` | ArgoCD app (managed by root-homelab) |

## The two-step 1.34 → 1.36 migration (IMPORTANT)

k3s docs: *"Ensure that your plan does not skip intermediate minor versions."*
We were on v1.34.6; stable is v1.36.2 — a 2-minor jump. So both plans are
**pinned to `version: v1.35.6+k3s1`** for the first transition.

### Step 1 — land on 1.35 (this is the deployed state)
- Plan `version: v1.35.6+k3s1`, window 06:30–08:00 UTC
- Controller upgrades k3s-home to 1.35.6, then k3s-nuc to 1.35.6.

### Step 2 — flip to stable, once 1.35 verified (A FUTURE COMMIT)
Edit BOTH `server-plan.yaml` and `agent-plan.yaml`: replace
`version: v1.35.6+k3s1` with
```yaml
channel: https://update.k3s.io/v1-release/channels/stable
```
Commit + push → controller picks it up and moves to 1.36 (next night's window).
From then on it tracks stable automatically for all future patches.

## Operations

```bash
# Progress
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs
kubectl -n system-upgrade get pods

# If a plan FAILED and a node is left cordoned:
kubectl -n system-upgrade get plan server-plan
kubectl uncordon k3s-home    # (and/or k3s-nuc)
```

Caveats:
- The controller **will not downgrade** and will **not** protect against
  skipping minors — keep the version/channel edits deliberate (see above).
- `cordon: true` means a node stays cordoned if its upgrade job fails;
  uncordon manually after fixing the cause.
- This runs on the single control-plane node (k3s-home) → expect an API-server
  + workload restart blip during each upgrade (single-replica apps restart).
