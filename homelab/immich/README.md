# Immich — Self-hosted Photo & Video Management

Accessible at **https://photos.k8s.hu.ls**

## Architecture

| Component | Image | Purpose |
|-----------|-------|---------|
| immich-server | `ghcr.io/immich-app/immich-server:release` | API + background workers (thumbnails, encoding, etc.) |
| immich-machine-learning | `ghcr.io/immich-app/immich-machine-learning:release` | CLIP search, facial recognition |
| Valkey (Redis) | `valkey/valkey:8-bookworm` | Job queue & caching |
| PostgreSQL | `tensorchord/cloudnative-vectorchord:16.9-0.4.3` | Metadata DB with VectorChord for AI search |

## Why a dedicated Postgres?

Immich requires the **VectorChord** extension (`vchord`) for vector similarity
search (smart search, facial recognition). The shared CNPG cluster runs vanilla
PostgreSQL 16 without this extension, so Immich gets its own CNPG Cluster
using the `cloudnative-vectorchord` image. It still uses the same CNPG operator.

## Storage

| PVC | StorageClass | Purpose |
|-----|-------------|---------|
| `immich-library` | `juicefs` | Photos, videos, thumbnails — replicated via Garage S3 |
| `immich-ml-cache` | `local-path` | ML model cache — can be re-downloaded |
| Postgres PVC | `local-path` | Database files (managed by CNPG) |

### JuiceFS for photo storage

JuiceFS provides compression and encryption over the Garage S3 backend. Your
photos get automatic replication across geo-distributed nodes via Garage, which
is exactly what you want for irreplaceable data. RWX access mode enables
RollingUpdate deployments for zero-downtime upgrades.

## Before deploying

1. **Change the DB password** in `postgres.yaml` → `immich-db-credentials` secret.
   Consider using a sealed-secret or external-secrets operator instead.

2. **Adjust resource limits** in `server.yaml` and `machine-learning.yaml` to
   match your nodes. ML inference is CPU-hungry; if you have a GPU node, look
   into `immich-machine-learning` GPU variants.

3. **Library PVC size**: default is 200Gi. Adjust in `pvc.yaml` based on your
   photo library size (~2-5 GB per 1000 photos with originals + thumbnails).

## Post-deploy

1. Open https://photos.k8s.hu.ls and create your admin account.
2. Install the Immich app on your phone (iOS / Android) and point it at the URL.
3. Configure storage templates, ML settings, and external libraries in
   Admin → Settings.
