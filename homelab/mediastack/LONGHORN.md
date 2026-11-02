# Longhorn storage and retained rollback sources

These workloads now use explicitly selected Longhorn claims with two replicas
on distinct nodes. All original local-path PVCs remain declared and Bound,
with Prune=false,Delete=false protection. Manual deletion is still destructive
because the old PVs use reclaimPolicy Delete. Owner approval is required for
any cleanup. Original claims are frozen pre-cutover copies, not current mirrors.

## prowlarr

- Active claim: `prowlarr-config-longhorn` (1Gi, two replicas).
- Retained source: `prowlarr-config-local`, UID `a6c0fbff-9fea-4848-baa2-3cc640276bee`.
- Cold copy: 778 files, 110547918 logical file bytes.
- Tree manifest SHA256: `7cdf693ad390079bfa7de795e29afede794d2bd30a1d28a632199fc12f8bfdd6`.
- Actual application verified on `k3s-home-2`, away from source `k3s-home`.

## bazarr

- Active claim: `bazarr-config-longhorn` (2Gi, two replicas).
- Retained source: `bazarr-config-local`, UID `eb2e2e0f-b655-4d5b-bf9d-ef2e7f40aa9b`.
- Cold copy: 43 files, 1452067 logical file bytes.
- Tree manifest SHA256: `203c8b147be8c01108e6f6c376be605a9cb999cabf8bc5ed650d66cb7c16ecb8`.
- Actual application verified on `k3s-nuc`, away from source `k3s-home`.

## sonarr

- Active claim: `sonarr-config-longhorn` (2Gi, two replicas).
- Retained source: `sonarr-config-local`, UID `2448b5c5-7698-48db-9f8a-b5e49b6a9ddf`.
- Cold copy: 721 files, 185390331 logical file bytes.
- Tree manifest SHA256: `f52477ad1962b65e98f7b7086316351dc8b7f568fd93dec88ae5b520936b53cb`.
- Actual application verified on `k3s-home-2`, away from source `k3s-home`.

## radarr

- Active claim: `radarr-config-longhorn` (2Gi, two replicas).
- Retained source: `radarr-config-local`, UID `2865fc86-4f91-448d-b0f8-b1987b44a470`.
- Cold copy: 585 files, 230725438 logical file bytes.
- Tree manifest SHA256: `94e542304b64a624e29ec915791cc8b03f35aada14db3344b0264d45748366c2`.
- Actual application verified on `k3s-nuc`, away from source `k3s-home`.

## sonarr-4k

- Active claim: `sonarr-4k-config-longhorn` (2Gi, two replicas).
- Retained source: `sonarr-4k-config-local`, UID `1406e818-c4c2-4532-9863-f988393099d8`.
- Cold copy: 382 files, 137444250 logical file bytes.
- Tree manifest SHA256: `bbd8775b8df0c70a44f7fbf1a35faf6138d553a807c3009b2c76cd949d0af84a`.
- Actual application verified on `k3s-home-2`, away from source `k3s-home`.

## radarr-4k

- Active claim: `radarr-4k-config-longhorn` (2Gi, two replicas).
- Retained source: `radarr-4k-config-local`, UID `b2367aeb-d204-45a1-9ddc-cf15a220c2c2`.
- Cold copy: 585 files, 267335371 logical file bytes.
- Tree manifest SHA256: `d7de97b4eb89df022c192c440e098652bcc80b263946e93bb69c0085e2acf4c7`.
- Actual application verified on `k3s-nuc`, away from source `k3s-home`.

## transmission

- Active claim: `transmission-config-longhorn` (1Gi, two replicas).
- Retained source: `transmission-config-local`, UID `d52999ad-6c94-4a0d-ac83-8259629326ab`.
- Cold copy: 876 files, 10665305 logical file bytes.
- Tree manifest SHA256: `19fbe89372dbd77d76c0cc1dccb4269327a83e89194c6fdc8c51b96a9ef53dbb`.
- Actual application verified on `k3s-home-2`, away from source `k3s-home`.

## qbittorrent

- Active claim: `qbittorrent-config-longhorn` (1Gi, two replicas).
- Retained source: `qbittorrent-config-local`, UID `fd9bdef3-b4a7-42bd-8727-a5a22851f6aa`.
- Cold copy: 676 files, 53016365 logical file bytes.
- Tree manifest SHA256: `0174ea238ce86b350dd9a982bfdc5a624dad4f39b5cb9b790dba830a5cca1ae9`.
- Actual application verified on `k3s-nuc`, away from source `k3s-home`.

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

qBittorrent web health passed and every config/resume file was verified. Its
authenticated API returns 403 without login both before and after migration;
an authenticated torrent-list test was not performed. Transmission RPC did pass,
with the same 429 torrent hashes and 69 active torrents after both reattachments.
