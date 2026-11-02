# BentoPDF

Stateless browser-side PDF tools at https://pdf.k8s.hu.ls behind Authentik.
Use the official self-hosted Simple build, pinned to a released image digest.
Two nginx replicas spread across nodes, with minAvailable=1 for voluntary drain.
No database, PVC, shared filesystem, or server-side PDF processing is needed.
Only nginx temporary directories use bounded emptyDir volumes.

Namespace ownership belongs to root-homelab, not this child Application.
TLS uses the existing reflector-managed wildcard Secret. COOP/COEP headers from
the image must be preserved so Office/WASM tools work over HTTPS.

Default WASM/OCR assets may download from CDNs; file processing remains in the
browser. This is not an air-gapped deployment or a server-side REST API.
Stirling's old claims/database are retained separately for rollback; never delete
the old local-path PVC or Longhorn PVC without explicit data-cleanup approval.
