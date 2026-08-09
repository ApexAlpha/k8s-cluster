# Garage S3 Restore and Velero Exclusion Plan

> **For Hermes:** Execute this plan through the GitOps repository and validate the restore path before relying on it.

**Goal:** Treat Garage as the S3 backup repository rather than backing up Garage's own live PVCs through Velero, while retaining a tested restore path from the encrypted Hetzner archive.

**Architecture:** The nightly `garage-to-hetzner` job reads Garage through its S3 API. `rclone crypt` encrypts and obfuscates the S3 objects locally before uploading them to Hetzner. Hetzner therefore contains logical S3 objects, not Garage's `meta` LMDB or raw `data` PVC directory. Recovery must run the rclone crypt decryption layer and restore the logical objects into a temporary/native S3-compatible endpoint before using Velero/Kopia.

**Tech Stack:** rclone 1.75.0, rclone crypt, Garage S3, Hetzner Object Storage, Velero/Kopia, Kubernetes/ArgoCD.

---

## Current state and decision

- Source: `garage:velero-backups` and `garage:postgres-backups` through Garage S3.
- Offsite target: `hcrypt-velero:` and `hcrypt-postgres:`; client-side encrypted with rclone crypt.
- `rclone copy` uploads new/changed logical S3 objects and does not delete destination objects.
- The job prunes objects older than 60 days and keeps monthly snapshots under a separate protected prefix.
- The scheduled Velero backup already excludes namespace `garage`; the additional pod annotation excludes Garage volumes from ad-hoc or otherwise misconfigured backups too.
- Do not copy a live Garage LMDB with generic filesystem backup as the normal path.

## Restore path A — rehydrate into a temporary Garage/S3 endpoint (preferred)

1. Provision a temporary Garage instance or another S3-compatible endpoint with enough capacity, isolated from production.
2. Mount the existing rclone configuration containing the Hetzner S3 and crypt remotes. Never print the config or credentials.
3. Verify the encrypted archive is readable through the crypt remote:

   ```bash
   rclone lsd hcrypt-velero: --config /path/to/rclone.conf
   rclone size hcrypt-velero: --config /path/to/rclone.conf
   ```

4. Create the destination bucket in the temporary S3 endpoint and configure an rclone remote for it, for example `garage-restore:`.
5. Copy the decrypted logical objects from the crypt remote into the temporary endpoint:

   ```bash
   rclone copy hcrypt-velero: garage-restore:velero-backups      --config /path/to/rclone.conf      --transfers 4 --checkers 8      --retries 5 --low-level-retries 10      --timeout 60s --retries-sleep 15s
   ```

6. Verify object counts, sizes, and representative read-back objects with `rclone check`/`rclone size` through the logical remotes.
7. Point Velero's temporary BackupStorageLocation at the restored S3 endpoint and verify the Kopia repositories before attempting an application restore.
8. Restore into a scratch namespace first. Do not point production Velero at the temporary endpoint until the scratch restore succeeds.

This path decrypts during the read and writes plaintext logical S3 objects to the temporary S3 endpoint. Garage rebuilds its own metadata as objects are written.

## Restore path B — re-encrypt with new rclone crypt credentials

Use this when the original crypt password/salt must be rotated or the original config is unavailable but the data can still be read.

1. Create a new crypt remote, for example `hcrypt2-velero:`, backed by the desired Hetzner bucket/prefix and a new password plus explicit salt.
2. Copy through the old crypt remote into the new crypt remote:

   ```bash
   rclone copy hcrypt-velero: hcrypt2-velero:      --config /path/to/rclone.conf      --transfers 4 --checkers 8      --retries 5 --low-level-retries 10      --timeout 60s --retries-sleep 15s
   ```

3. Verify the new remote by comparing logical listings/sizes and reading representative objects through `hcrypt2-velero:`.
4. Keep the old encrypted archive until the new archive has passed verification and a scratch restore.
5. Update the sealed rclone configuration only after validation; never store the new password or salt in Git as plaintext.

Rclone decrypts objects from the old remote and re-encrypts them for the new remote. Copying raw objects directly at the underlying Hetzner S3 remote would not re-encrypt or preserve usable logical names.

## Restore path C — direct temporary S3 exposure

A temporary rclone-backed S3 endpoint can expose the decrypted crypt remote, but this is a recovery-only option and should be validated before depending on it. It adds another service and process to the restore chain. Prefer rehydrating into a real temporary Garage/S3 endpoint for a repeatable restore.

## Validation checklist

- Confirm the crypt remote can list and read the archive.
- Confirm logical object count and total size after rehydration.
- Confirm the Velero/Kopia repository is recognized by the temporary BackupStorageLocation.
- Run a scratch Velero restore of one non-production application.
- Restore a representative PVC and verify application data.
- Record the exact rclone image/version, endpoint configuration, and secret locations without recording credentials.

## Velero change

Add the pod annotation below to the Garage deployment template:

```yaml
backup.velero.io/backup-volumes-excludes: meta,data
```

The existing scheduled backup namespace exclusion remains the primary protection. The pod annotation is defense-in-depth for manual backups that accidentally include the Garage namespace. Verify the live Garage pod carries the annotation and that a new test backup creates no Garage PVBs.
