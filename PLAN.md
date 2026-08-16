# Security Data & Reporting Platform — Implementation Plan

**Owner:** Jules Huls  
**Date:** 2026-08-16  
**Status:** Demo deployed; ingestion/full flow in progress

---

## 1. Goal

Build an on-prem security-data analytics and reporting platform that:

1. Ingests exports from Rapid7, Microsoft Defender, and Aqua Security.
2. Normalizes them onto a unique asset ID (cloud ID).
3. Enriches assets with other sources: autopatching status, scanner coverage, technology stack, and SAFe team/ART ownership.
4. Exposes KPI dashboards/reports to the team via self-hosted Metabase.

Everything stays **on-prem** (sensitive data). No new commercial security platform — we own the pipeline.

**Non-goals (phase 1):** no remediation/ticketing workflows, no real-time streaming, no commercial platform.

---

## 2. Context / confirmed constraints

| Topic | Decision |
|---|---|
| Data location | On-prem (home cluster). Cloud DuckDB (MotherDuck) rejected by default. |
| Dashboards | **Metabase** (self-hosted). |
| Analytics engine | **DuckDB** for analytical/report snapshots; **PostgreSQL** for canonical normalized data + enrichment. |
| Writes | A single importer (person or cron) is the only writer. |
| Metabase metadata | PostgreSQL (already dedicated `metabase` DB). |
| Metabase auth | Free OSS edition → local accounts behind Authentik forward-auth (OIDC is Pro/EE-only). |
| Volume | >1M findings expected — both PG and DuckDB handle this. |
| Sensitive data | On-prem only; [REDACTED] for any secrets. |

---

## 3. Cluster deployment status (completed)

Metabase `v0.59.28` is running GitOps-managed in the home cluster.

| Resource | Value |
|---|---|
| URL | https://metabase.k8s.hu.ls |
| Namespace | `metabase` |
| Postgres app DB | CNPG `postgres-shared` → dedicated `metabase` DB + `metabase_user` role |
| Credentials | SealedSecrets |
| Ingress | Traefik + Authentik forward-auth |
| Git path | `homelab/metabase/` |

### DuckDB analytics (completed)

- Custom Debian-based (eclipse-temurin 21) image + Metabase JAR + DuckDB community driver (`1.5.5.0`), both SHA-256 pinned, installed by an init container.
- PVC `metabase-duckdb` (20 Gi, local-path) mounted read-only at `/data`.
- Seed job populated `/data/security.duckdb`:
  - `assets` — 50,000 rows
  - `findings` — 1,000,000 rows
  - `current_finding_posture` — joined view
  - `kpi_summary` — aggregate view
- Driver verified in logs: `Registered driver :duckdb`.
- In Metabase: Admin → Databases → Add database → **DuckDB**, file `/data/security.duckdb`, enable *Read only* + *old_implicit_casting*.

GitOps commits: `54e3f45`, `db13e01`, `25d013b`, `db79e97`, `c5427aa`.

---

## 4. Data architecture

```text
Scanner exports / APIs
   ├─ Rapid7
   ├─ Microsoft Defender
   └─ Aqua
        │
        ▼
 Raw staging (immutable files)
   CSV / JSON / Parquet
        │
        ▼
 Import + normalize scripts (Python)
        │
        ▼
 PostgreSQL canonical models
   (identity, asset, finding, observation, enrichment)
        │
        ├─ operational / API / manual edits
        └─ periodic snapshot → Parquet → DuckDB
                                      │
                                      ▼
                                   Metabase
```

### Principles

1. **Intentionally not treating scanners as the system of record.** Treat them as evidence sources. Keep immutable import batches and raw records for replay.
2. **Do not use the scanner finding ID as identity.** Identity is the canonical asset, canonical finding, and observation.
3. **Append+snapshot history rather than destructive updates.** Preserve first-seen/last-seen/resolved, and treat missing records as "not observed," not "resolved."
4. **Enrichment is separate from the asset, store overrides/confidence.**
5. **Single orchestrated pipeline:** one `run` imports, normalizes, enriches, builds views, and writes KPI snapshots — avoids partially updated dashboards.
6. **DuckDB file is read-only to Metabase; rotate via atomic snapshot swap.**

---

## 5. Canonical data model

### Core tables

| Table | Purpose | Key columns |
|---|---|---|
| `import_batch` | Track each import run | source, file_hash, imported_at, parser_version, row_count, status |
| `raw_scanner_record` | Immutable raw per-scanner data | import_batch_id, scanner, payload, record_hash |
| `asset` | Canonical asset | asset_id, type, environment, criticality, provider/account/region, first/last_seen |
| `asset_identifier` | Alias mapping | identifier_type, identifier_value, source, confidence |
| `vulnerability` | Canonical problem/vuln | type (cve/pkg/misconfig/policy), cve, vendor, severity |
| `finding` | Canonical asset×problem | finding_id, asset_id, vulnerability_id, package/location, status, severity, first/last_seen, resolved_at |
| `scanner_observation` | What each scanner actually said | finding_id, scanner, scanner ids, observed_at, scanner_severity/status, import_batch_id |
| `data_quality_issue` | Unmatched/ambiguous rows | asset/finding references, issue type, resolution status |

### Enrichment tables

| Table | Purpose |
|---|---|
| `technology_stack` | stack definitions |
| `asset_stack` | many-to-many asset↔stack |
| `org_unit` | SAFe hierarchy (portfolio → value stream → solution → ART → team → department) |
| `stack_org_assignment` | stack ↔ org, validity |
| `asset_org_assignment` | asset ↔ org direct overrides |
| `asset_control_status` | scanner coverage / autopatching / EDR (control_type, provider, status, observed_at) |

Rollup path for KPIs:
`finding → asset → technology stack → team → ART → solution/value stream`.

### User-planned reporting views

- `current_asset_posture`
- `current_finding_posture`
- `scanner_coverage`
- `team_vulnerability_summary`
- `vulnerability_trends`
- `data_quality_dashboard`
- `kpi_summary` (in DuckDB demo)
- Team / ART KPI snapshot tables for historical trends.

---

## 5. Decisions & justifications

### 5.1 PostgreSQL vs DuckDB
- **PostgreSQL** (`postgres-shared`): canonical data, concurrent ops, manual enrichment edits, transactionality, app/API access. Handles >1M rows.
- **DuckDB** (PVC, read-only): batch analytics, Parquet scans, fast sessions/dashboards, minimal admin.
- Combined: PG canonical + DuckDB analytical snapshot. Deferred if only pure-batch reporting is needed.

### 5.2 UI
- **Metabase** (OSS).
- OIDC/SSO + auto-user-provisioning is **Pro/Enterprise only**. Options:
  1. Keep Authentik forward-auth + local Metabase accounts (free) — currently in use.
  2. Buy Pro when SSO becomes a hard requirement.

### 5.3 Why not "another platform"
- No onboarding/maintenance or contractual lock-in.

---

## 6. Phased roadmap

### Phase 0 — Platform foundation ✅ (demo ready)
- Metabase + DuckDB + seeded demo data running.
- Verify DuckDB DB list shows in Metabase UI (manual step).

### Phase 1 — Importer framework
- `security_data` Python package (source-specific parsers).
- Immutable raw archive.
- `import_batch` + `raw_scanner_record`.
- CLI:
  - `python -m security_data import rapid7 <file>`
  - `python -m security_data import defender <file>`
  - `python -m security_data import aqua <file>`
- Store canonical data in PostgreSQL (dedicated DB/role — mirror Metabase pattern).
- Deliverable: end-to-end import of one real export per scanner into canonical tables.

### Phase 2 — Identity resolution & enrichment
- Deterministic matching: cloud ID → instance ID → hostname+account → IP → manual review.
- `identity_match`/review queue with confidence.
- Enrichment imports: asset inventory, autopatching, coverage, team mappings (Git-managed CSV/YAML initially).
- Deliverable: single authoritative asset list with all enrichment joining.

### Phase 3 — Reporting layer
- Build current-state views + KPI snapshots (Metabase).
- DuckDB snapshots regeneration on schedule (rotate file).
- Team / ART / SAFe rollups.
- Deliverable: team-facing Metabase dashboard over real data; trend charts.

### Phase 4 — Scheduling & quality
- Orchestrated nightly pipeline (cron).
- Data-quality reports (unmatched, missing, overlapping).
- Alerts on pipeline failures.
- Deliverable: hands-off scheduled refresh + quality gate.

### Phase 5 — Presentation polish (optional)
- Dashboard subscriptions/emails.
- Role-based access refinement.

---

## 7. Open decisions / blockers

- Need **sanitized sample scanner exports** (Rapid7 `defender`/`aqua`) to write real parsers.
- Choose a **naming for the canonical `asset_id`** (won highest-level) and confirm cloud-ID availability in each scanner export.
- Confirm **which fields are available** from each API/export for identity and coverage.
- Decide whether to keep spreadsheet/CSV enrichment initially vs an app/backend.
- Optional: password-protect Metabase vs OIDC — informal cost call.
- DuckDB file rotation: decide snapshot cadence / retention with importer.

---

## 8. Deliverables (next 4 weeks cadence)

1. Fix importer framework + one live parser (Defender CSV).
2. Sanitized demo records from user.
3. Run first real import into PostgreSQL.
4. Build `current_finding_posture` + first dashboard in Metabase.
5. Deliver identity-resolution pass + enrichment files.
6. Deliver DuckDB snapshot generation + scheduled nightly pipeline.

---

*Secrets are not part of this repo; `.env`/SealedSecrets hold credentials only. Hardcoded `~/.hermes`/home paths are avoided. Dashboard/state lives via profile-aware `get_hermes_home()`.*