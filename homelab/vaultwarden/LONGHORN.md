# Longhorn storage and retained rollback sources

These workloads now use explicitly selected Longhorn claims with two replicas
on distinct nodes. All original local-path PVCs remain declared and Bound,
with Prune=false,Delete=false protection. Manual deletion is still destructive
because the old PVs use reclaimPolicy Delete. Owner approval is required for
any cleanup. Original claims are frozen pre-cutover copies, not current mirrors.

## vaultwarden

- Active claim: `vaultwarden-data-longhorn` (5Gi, two replicas).
- Retained source: `vaultwarden-data-local`, UID `d6a9543a-9b06-4506-87f1-76baab586c11`.
- Cold copy: 167 files, 897013 logical file bytes.
- Tree manifest SHA256: `822b171b01f2d3beedb1af422a00d3a10a9553defd7b6ad99fd0eb006f2649f7`.
- Actual application verified on `k3s-home`, away from source `k3s-nuc`.

## Verified invariants

Writers were stopped and all app pods terminated before copying. Sources were
mounted read-only. File content, UID/GID, modes, timestamps, symlinks and source
stability were compared. Temporary migration Jobs and node placement were then
removed, followed by readiness/API checks. Images, database configuration and
other mounts were unchanged. Bulk NFS payloads were not copied or modified.

To roll back, scale the affected Deployment to zero in Git, wait for all writers
to exit, switch its data claim reference to the retained source, then restore one
replica via GitOps. Consider any configuration changes since cutover before
using the frozen source. Do not delete the new Longhorn claim during rollback.
