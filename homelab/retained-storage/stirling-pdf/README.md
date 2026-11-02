# Retained Stirling PDF data

Stirling was replaced by stateless BentoPDF at https://pdf.k8s.hu.ls.
There is no Stirling Application, Deployment, Service or ingress anymore.
These retained resources are managed directly by root-homelab:

- Namespace stirling-pdf.
- stirling-pdf-data-local (2 GiB local-path, original UID
  9ef5229c-5e39-49ca-8323-3bc62120649f).
- stirling-pdf-data-longhorn (2 GiB, two replicas, UID
  1e154da1-6d0d-4436-a3f2-bed1c19efa45).
- The existing sealed database credential and retained CNPG Database resource
  for database stirling, owned by stirling_user in postgres-shared.

No application data was deleted. The namespace's default-deny-ingress policy
remains, while obsolete application and PostgreSQL ingress allowances were
removed. The DB role remains under the existing CNPG cluster configuration.
Both PVCs have Prune=false,Delete=false protections. Manual deletion of the
local-path claim is still destructive because its PV uses reclaimPolicy Delete.
Cleanup or database deletion requires explicit owner approval.

MIGRATION.md records the verified Longhorn copy and the pre-existing paid
external-database processing limitation in Stirling 3.2.2. It is historical
validation, not a currently running Stirling deployment.

For rollback, restore Stirling manifests and namespace-specific network access
from commit 11c33b7116719ea791a8f557456f0d713d044258, reference the desired retained
claim, and avoid duplicate ownership of retained resources. Test privately
before switching the protected PDF hostname back. Account for Stirling's
external-database licence requirement; do not downgrade merely to evade it.
