# Longhorn storage and retained rollback sources

These workloads now use explicitly selected Longhorn claims with two replicas
on distinct nodes. All original local-path PVCs remain declared and Bound,
with Prune=false,Delete=false protection. Manual deletion is still destructive
because the old PVs use reclaimPolicy Delete. Owner approval is required for
any cleanup. Original claims are frozen pre-cutover copies, not current mirrors.

## shelfmark

- Active claim: `shelfmark-config-longhorn` (10Gi, two replicas).
- Retained source: `shelfmark-config`, UID `8c00dedc-dfd3-40c5-bd72-5e4c3531b9e4`.
- Cold copy: 237 files, 11193145 logical file bytes.
- Tree manifest SHA256: `53494efc2c72af1466885b77448a5c3a17f3cadf2d668c3c1c1835838780952a`.
- Actual application verified on `k3s-home-2`, away from source `k3s-home`.

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
