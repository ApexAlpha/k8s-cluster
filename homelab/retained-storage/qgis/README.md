# Retired QGIS storage

QGIS was removed at the owner's request. Only the namespace and qgis-home PVC
remain, managed by root-homelab, to preserve files without running the app.

Do not delete this namespace or PVC without explicit data-deletion approval.
The local-path PV has reclaimPolicy Delete: deleting the claim deletes its data.
The 20Gi claim is provisioned capacity, not measured disk usage.
