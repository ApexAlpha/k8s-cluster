# system-upgrade (k3s automated stable upgrades)

ArgoCD's `root-homelab` owns `application.yaml`; this child app owns the CRD,
controller and Plans. Do not include `application.yaml` in the child's kustomization.

Both Plans track `https://update.k3s.io/v1-release/channels/stable`.
When enabled for stable, all three nodes were `v1.36.4-rc1+k3s1`, and the
channel resolved to `v1.37.2+k3s1` (one adjacent minor). Later stable releases
may trigger new rolling upgrades inside the maintenance window. Monitor for
version-skew gaps if a node has been unavailable for multiple minor releases.
Upgrade images must be **untagged** `rancher/k3s-upgrade`: the controller appends
the channel's resolved version tag. A pinned image digest here can install the
wrong binary or fail as a downgrade when the channel changes. The controller
image itself is pinned separately. The job's kubectl helper is pinned to a
Kubernetes 1.36 image, compatible with 1.36 and 1.37 API servers.

At 02:00-03:00 `Europe/Amsterdam`, the controller upgrades one node at a time,
with 5 minutes after each completed node before starting the next. All three
nodes are control-plane/etcd, so only `server-plan` selects them; `agent-plan`
waits for `server-plan` and is for future worker-only nodes. The Plans cordon
but do not drain: this protects local-path/pinned workloads from forced eviction,
not from a brief service interruption during a k3s restart. Three etcd members
preserve API quorum when only one is unavailable, **not** availability of every
single-replica or hardware-bound app. This does not reboot the OS.

Initial verification (outside the maintenance window):

```bash
kubectl -n argocd get application root-homelab system-upgrade
kubectl -n system-upgrade get deployment system-upgrade-controller
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs
kubectl get nodes -o wide
```

After the first window, check all three node versions, Ready/schedulable status,
`Plan.status.conditions`, completed Jobs/logs, app readiness and Velero's BSL.
A failed job may leave a node cordoned: diagnose the error *before* manually
uncordoning. `window` prevents creating new Jobs outside its hours, but a Job
started in the window may continue past its end.
