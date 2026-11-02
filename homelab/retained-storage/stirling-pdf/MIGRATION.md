# Stirling PDF storage

Stirling now uses `stirling-pdf-data-longhorn`: a 2 GiB ReadWriteOnce claim
explicitly selecting the `longhorn` StorageClass. It has two healthy replicas
on distinct nodes. PostgreSQL configuration, image and ingress authentication
were not changed by the storage migration.

## Verification

The app was stopped through GitOps before copying. A one-shot Job on k3s-nuc
mounted the source PVC read-only and copied the complete tree to Longhorn.
It verified SHA256 file content, UID/GID, modes, timestamps, symlink targets and
source stability: 10 files and 9 directories, 184091 file bytes, matching tree
manifest SHA256 `6bef47ed6debd8100d894ccf37f3665c4eda39debfa6124001b5c3870512d2f5`.
The Job used a cached pinned Stirling image, no API token or database secrets,
and was removed after successful verification.

Stirling then started successfully on k3s-home-2, away from the original
local-path source on k3s-nuc. Its Longhorn engine attached on k3s-home-2 while
the two data replicas were on k3s-nuc and k3s-home. The health API returned
`{"version":"3.2.2","status":"UP"}`. Temporary node placement was then removed
so the scheduler can choose any eligible node.

## Retained rollback source

`stirling-pdf-data-local` remains Bound and declared in `pvc.yaml`, but is not
used by the Deployment. Both claims carry Prune=false,Delete=false protection.
Do not delete the old claim: its PV reclaimPolicy is Delete and would destroy
the retained source data. Explicit owner approval is required for later cleanup.
This is a pre-cutover copy, not a continuously updated mirror or backup.

To roll back, quiesce Stirling through GitOps, wait until all app pods terminate,
change the Deployment's data claim reference back to `stirling-pdf-data-local`,
and restore one replica through GitOps. The local PV will place it on k3s-nuc.
Consider any settings changed since cutover before reverting to the retained
pre-migration configuration. Do not delete the Longhorn claim during rollback.

## Pre-existing application limitation

Before migration, POST /api/v1/convert/pdf/text returned HTTP 402 with
SERVER_PLAN_REQUIRED: the current Stirling release requires a paid Team account
or Server/Enterprise licence to use this database configuration. The same
request produced the identical response after migration. Storage mobility and
health were verified; PDF conversion is NOT verified working. Do not claim this
is caused by Longhorn or silently change PostgreSQL/licensing settings to fix it.
