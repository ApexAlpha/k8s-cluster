# Longhorn storage and retained rollback sources

These workloads now use explicitly selected Longhorn claims with two replicas
on distinct nodes. All original local-path PVCs remain declared and Bound,
with Prune=false,Delete=false protection. Manual deletion is still destructive
because the old PVs use reclaimPolicy Delete. Owner approval is required for
any cleanup. Original claims are frozen pre-cutover copies, not current mirrors.

## mealie

- Active claim: `mealie-data-longhorn` (5Gi, two replicas).
- Retained source: `mealie-data-local`, UID `ad1eebea-47db-4859-8d0c-34269578c57a`.
- Cold copy: 13 files, 38257102 logical file bytes.
- Tree manifest SHA256: `dad952d9ee0c02534526a6636e1d7336aae22b72da4cb1e37982674f37ff6a7a`.
- Actual application verified on `k3s-home-2`, away from source `k3s-nuc`.

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
