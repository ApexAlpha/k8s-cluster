# Longhorn storage and retained rollback sources

These workloads now use explicitly selected Longhorn claims with two replicas
on distinct nodes. All original local-path PVCs remain declared and Bound,
with Prune=false,Delete=false protection. Manual deletion is still destructive
because the old PVs use reclaimPolicy Delete. Owner approval is required for
any cleanup. Original claims are frozen pre-cutover copies, not current mirrors.

## hister

- Active claim: `hister-data-longhorn` (10Gi, two replicas).
- Retained source: `hister-data`, UID `ee6bbc70-bfbd-42ca-ba6a-35419a9348d6`.
- Cold copy: 3383 files, 890738829 logical file bytes.
- Tree manifest SHA256: `7e5bc705a9e54e294c58543a1507b57f8cb7907ac2e2a5d7c9beb7e3ef91ee46`.
- Actual application verified on `k3s-home`, away from source `k3s-home-2`.

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

## Separate image-pull caveat

A fresh Hister pull via kubelet/CRI on home returned GHCR 403, while anonymous
HTTP and direct containerd pulls succeeded. The identical pinned public image
was cached under its canonical repo@digest name on home and nuc; VM2 already
had it. Hister then passed the cross-node test. No node registry credentials or
k3s services were changed. This cache preparation does not fix the underlying
CRI registry-auth path: future image updates or cache eviction may expose it
again. Resolve node-level GHCR credentials separately before relying on fresh
pulls; do not claim the registry problem was permanently repaired.
