# PostgreSQL to S3-Compatible Storage FDW Proof of Concept

## Status

**Pending manual execution.** The artifacts below were prepared and reviewed against authoritative
Wrappers/PostgreSQL documentation, but the actual build and query run require `podman`
container-build access that was not available in the environment that authored this document. Every
result field in this document must be filled in from a real run before any suitability claim is
treated as verified. Do not treat this document as evidence of feasibility until the "Results"
section below is populated with actual command output.

## Question

Can this PostgreSQL environment query structured objects (CSV, JSON Lines, Parquet) stored in the
local RustFS S3-compatible service through a practical FDW implementation?

This is a feasibility question only. A successful `SELECT` does not prove production suitability.
See "Explicitly out of scope" below.

## Mechanism Evaluated

[Supabase Wrappers](https://github.com/supabase/wrappers), specifically its S3 wrapper (`s3_fdw`).
Wrappers is a Rust framework for PostgreSQL foreign data wrappers, built on `pgrx`. The S3 wrapper:

- Is **read-only** (no INSERT/UPDATE/DELETE/TRUNCATE).
- Supports CSV (with or without header), JSON Lines, and Parquet, with gzip/bzip2/xz/zlib
  compression.
- Accepts a custom `endpoint_url`, which is how it targets RustFS instead of AWS S3.

PostgreSQL 17 support was unconfirmed in Wrappers' documentation as of this PoC's authoring date, so
the PoC image pins **PostgreSQL 16** — isolated from the permanent `psql-pub` image (17.7), so this
has no bearing on the production database version.

## Explicitly Out of Scope

Per the approved plan, this PoC does not implement or validate:

- Writes, updates, or deletes.
- Bulk export or archival workflows.
- Rails model integration, Active Storage, Shrine, or CMS Media integration.
- AWS S3 verification. Any AWS compatibility claim below is an **unverified expectation** based on
  the S3-compatible API, not a tested result.
- Permanent automated application tests.

## Artifacts

| Path                                           | Purpose                                                                                                                                      |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `podman/fdw-poc/Containerfile`                 | Disposable PostgreSQL 16 image with Wrappers' `s3_fdw` built via `cargo pgrx install`.                                                       |
| `podman/fdw-poc/compose.fdw-poc.yml`           | Opt-in Compose overlay (`fdw-poc` profile), tmpfs-backed PGDATA, isolated from `compose.yaml`.                                               |
| `podman/fdw-poc/fixtures/generate_fixtures.sh` | Generates tiny CSV/JSONL/Parquet fixtures and uploads them to RustFS.                                                                        |
| `podman/fdw-poc/smoke/run_smoke_checks.sql`    | Read-only smoke checklist: SELECT, projection, filter, COUNT, missing-object, invalid-credential, and two schema-mismatch cases, per format. |

## Reproduction Steps

Run all of this on the host (or inside `core`, if it has `podman`, `aws` CLI, and `duckdb`
available) — this environment does not.

1. Ensure RustFS is running (see `docs/operations/local-object-storage-rustfs.md`):

   ```sh
   COMPOSE="podman compose -f compose.yaml"
   $COMPOSE --profile object-storage up -d rustfs-permissions rustfs
   ```

2. Generate and upload fixtures:

   ```sh
   export OBJECT_STORAGE_ENDPOINT=http://127.0.0.1:9000   # host-reachable RustFS port
   export OBJECT_STORAGE_ACCESS_KEY_ID=...                 # same value used to start RustFS
   export OBJECT_STORAGE_SECRET_ACCESS_KEY=...
   ./podman/fdw-poc/fixtures/generate_fixtures.sh
   ```

3. Build and start the disposable FDW PoC container:

   ```sh
   export FDW_POC_POSTGRES_PASSWORD=...   # any local-only value; never reuse a real credential
   $COMPOSE -f podman/fdw-poc/compose.fdw-poc.yml \
     --profile object-storage --profile fdw-poc \
     up -d --build rustfs-permissions rustfs fdw-poc
   ```

4. Before running the checklist, edit `podman/fdw-poc/smoke/run_smoke_checks.sql`: replace
   `CHANGEME_ACCESS_KEY` / `CHANGEME_SECRET_KEY` with the same `OBJECT_STORAGE_ACCESS_KEY_ID` /
   `OBJECT_STORAGE_SECRET_ACCESS_KEY` used above, and confirm the `CREATE SERVER` /
   `CREATE USER MAPPING` option names against the pinned Wrappers version's S3 FDW reference (some
   releases use Vault-based credential storage instead of plain user-mapping options — adjust if
   so).

5. Run the checklist and capture full output, including errors verbatim:

   ```sh
   $COMPOSE -f podman/fdw-poc/compose.fdw-poc.yml \
     --profile object-storage --profile fdw-poc \
     exec -T fdw-poc psql -U fdw_poc -d fdw_poc -v ON_ERROR_STOP=0 \
     -f /dev/stdin < podman/fdw-poc/smoke/run_smoke_checks.sql \
     | tee podman/fdw-poc/smoke-results.txt
   ```

6. Paste the captured output (or a faithful summary with exact error text) into the "Results"
   section below.

## Results

_(Fill in after running step 5. Do not summarize away exact error messages — they are the evidence
for the Limitations section.)_

| Check                            | CSV     | JSON Lines | Parquet |
| -------------------------------- | ------- | ---------- | ------- |
| `SELECT *`                       | pending | pending    | pending |
| Projection                       | pending | pending    | pending |
| Filter                           | pending | pending    | pending |
| `COUNT`                          | pending | pending    | pending |
| Missing object                   | pending | pending    | pending |
| Invalid credentials              | pending | pending    | pending |
| Schema mismatch (type)           | pending | —          | —       |
| Schema mismatch (missing column) | pending | —          | —       |

## Capabilities

_(Fill in based on Results — e.g. "predicate pushdown observed" or "full scan observed via EXPLAIN,"
only if actually checked.)_

## Limitations

_(Fill in from actual failure-mode output — e.g. exact error text for missing object / invalid
credentials / schema mismatch, and whether the wrapper failed loudly or silently produced wrong
data.)_

## Operational and Security Concerns

- The S3 wrapper is read-only by design, which limits blast radius but does not by itself make
  credential handling safe — confirm whether the pinned Wrappers version stores S3 credentials in
  plaintext catalog options or Postgres Vault, and record that choice here.
- The PoC container has no persistent volume (tmpfs PGDATA) and is deleted per the cleanup manifest
  below — it must never be treated as a long-lived service.
- Native compilation (`cargo pgrx install`) requires a real Rust toolchain and build tooling inside
  the PoC image; this is intentionally isolated from `psql-pub` and must not be replicated into the
  permanent database image without a separate, explicitly approved decision.

## AWS S3 Compatibility

**Not verified.** RustFS implements an S3-compatible API, and the Wrappers S3 wrapper accepts a
custom `endpoint_url`, so AWS S3 compatibility is a plausible, unverified expectation only. No AWS
S3 test was performed or is in scope for this PoC.

## Suitability Verdict

_(Fill in after Results are recorded. Do not overstate: a successful local SELECT against RustFS is
evidence of local feasibility only, not of production readiness, AWS S3 compatibility, or acceptable
operational characteristics at scale.)_

## Cleanup Manifest (Gate 2c)

Run after the findings above are recorded. This removes every disposable artifact except this
document.

```sh
COMPOSE="podman compose -f compose.yaml"

# 1. Stop and remove the PoC container (tmpfs PGDATA is discarded automatically).
$COMPOSE -f podman/fdw-poc/compose.fdw-poc.yml \
  --profile object-storage --profile fdw-poc down fdw-poc

# 2. Remove the built PoC image.
podman image rm "$(podman images --format '{{.Repository}}:{{.Tag}}' \
  | grep -m1 fdw-poc)" || true

# 3. Remove the fixture objects and bucket from RustFS (adjust endpoint/creds as
#    used in the reproduction steps).
aws --endpoint-url "$OBJECT_STORAGE_ENDPOINT" s3 rm \
  "s3://${FDW_POC_BUCKET:-fdw-poc-bucket}" --recursive
aws --endpoint-url "$OBJECT_STORAGE_ENDPOINT" s3 rb \
  "s3://${FDW_POC_BUCKET:-fdw-poc-bucket}"

# 4. Remove the repository files (this document is intentionally excluded).
git rm -r podman/fdw-poc/Containerfile podman/fdw-poc/compose.fdw-poc.yml \
  podman/fdw-poc/fixtures podman/fdw-poc/smoke
```

After this manifest is executed, only this document remains as the permanent record of the PoC.
