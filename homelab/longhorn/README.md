# Longhorn scheduling foundation

New v1 volumes request two replicas on distinct nodes. Existing UniFi and
Lea/Louke volumes retain their three replicas.

The Helm key is persistence.defaultClassReplicaCount, not a root-level
key. defaultSettings.defaultReplicaCount.v1 controls the global default.
Changes apply to new volumes, not existing claims. Always specify
storageClassName explicitly: both local-path and longhorn currently advertise
default; changing that cluster-wide policy is deferred to the migration decision.

## Host prerequisites
All three hosts had active multipathd but no multipath maps (only LVM maps).
The unused daemon and socket were masked and stopped on each host:

    sudo systemctl mask --now multipathd.service multipathd.socket

No reboot or k3s restart was needed. If multipath storage is introduced later,
configure Longhorn-device exclusions before unmasking it.

## Migration boundary
local-path PV affinity pins other apps even without a nodeSelector. Migration
needs a new claim, stopped writers for the final copy, data verification and a
retained rollback source. Do not move shared PostgreSQL (app-level replicated),
or hardware-bound Plex/Home Assistant/Frigate just to gain scheduling freedom.
k3s-home-2 has a small root filesystem: check free space before adding replicas.
Do not lower safety thresholds to make scheduling pass.

Sources:
- https://longhorn.io/docs/1.13.0/references/storage-class-parameters/
- https://longhorn.io/docs/1.13.0/nodes-and-volumes/nodes/scheduling/
- https://longhorn.io/kb/troubleshooting-volume-with-multipath/

## Cross-node validation

A disposable 1 GiB PVC explicitly using storageClassName: longhorn was created
through root-homelab. A restricted Job wrote a probe on k3s-home, and a second
restricted Job read the same PVC on k3s-nuc after CSI detach/reattach. Both
returned SHA256 a69efed39a5e2c72d40661d53d77b3d4c8626f710e719aa3a234374042c5c164.
Longhorn reported exactly two healthy replicas, on k3s-home and k3s-nuc.
The disposable namespace, Jobs, PVC and Longhorn test volume were then removed.

NUC already has a single configured Longhorn disk, nvme-xfs at /mnt/nvme on
/dev/nvme0n1 (Samsung 990 EVO Plus 2TB, XFS), not its boot SSD. All NUC replica
paths point there. The filesystem is shared with other data: it is not empty.
Before copying any app data, inspect current usage rather than formatting it.

VM2 had a 132 GiB virtual boot disk, a 130 GiB LVM PV/VG, and a 65 GiB root LV;
the remaining 65 GiB was free in the VG. Check pvs/vgs/lvs before requesting
Proxmox expansion. Expanding a root LV remains a separately approved operation.
