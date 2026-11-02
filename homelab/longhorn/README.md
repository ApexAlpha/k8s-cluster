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
