# Round 3: `bin/rails test` boot-phase speedup (worker count by physical cores + cheap clone staleness check)

**Execution note:** the agent runs on the HOST. All Rails commands run inside core via
`podman compose -f compose.yaml -f .devcontainer/compose.override.yml exec -T core bash -lc '...'`.
Postgres checks via `podman exec global-devcontainer-primary ...`.

## Context

Rounds 1–2 (done): WAL-exhaustion write failures fixed; DB tuning (autovacuum off, auto_explain
removed, unlogged tables enabled for future rebuilds); PARALLEL_WORKERS=32 measured as a net loss
and reverted. Current: 3m28s wall, test phase 171.5s, 9115 runs, 0 failures. Host is 16C/32T — user
direction: derive parallelism from PHYSICAL core count, and attack the boot phase (~35s before tests
run). User will restart podman afterward and re-measure (restart wipes tmpfs → DBs rebuild →
unlogged tables take effect then).

Boot-phase cost analysis (test/support/parallel_test_database_cloner.rb):

- `rebuild_stale_worker_clones` runs once pre-fork but iterates **40 test DBs × 16 workers = 640
  clones** (cloner.rb:83-102). For every existing clone it computes `database_fingerprint`
  (cloner.rb:170-209): opens a **fresh PG connection** and runs `SELECT count(*)` on **every table**
  plus schema_migrations/ar_internal_metadata reads. 640 connections + full-table count scans per
  invocation = the dominant pre-test cost.
- Fingerprints/schema_sha for replica DBs are already aliased from base (cloner.rb:77-81).
- `schema_sha` = SHA1 of the structure.sql file (cheap, cloner.rb:155-158), stored in each clone's
  ar_internal_metadata (cloner.rb:211-227).
- `PARALLEL_WORKERS` fallback is a hardcoded `"16"` string (test/test_helper.rb:218);
  concurrent-ruby 1.3.7 is in Gemfile.lock → `Concurrent.physical_processor_count` usable.

## Changes

### R3-1. Worker count = physical cores (test/test_helper.rb)

Replace the hardcoded `"16"` fallback with `Concurrent.physical_processor_count.to_s` in
`Integer(ENV.fetch("PARALLEL_WORKERS", ...), 10)`. `PARALLEL_WORKERS` env still overrides;
COVERAGE=1 still forces 1. On this host physical cores = 16 → same value, but now self-tuning on
other machines. Add a one-line comment stating why physical (not logical) cores: measured — 32
logical workers lost more in fork/clone overhead than they gained.

### R3-2. Cheap clone staleness check (test/support/parallel_test_database_cloner.rb)

Replace the per-clone full `database_fingerprint` (connection + all-table count(*)) with a two-tier
check:

1. One catalog query on the maintenance connection listing all existing `*_N` clone DBs
   (`select datname from pg_database`) — replaces per-clone existence probes.
2. Per existing clone, read only `ar_internal_metadata` `schema_sha` (single-row query) and compare
   against the base's structure.sql SHA1. Rebuild the clone only when missing or sha differs. Drop
   the per-table `count(*)` data fingerprint for CLONES entirely: clones are recreated from template
   whenever schema changes, and test writes inside clones are rolled back by transactional fixtures
   — data drift protection is not worth 640 full scans per run (dev-volatile, speed-over-integrity
   direction). Keep the base-DB fingerprint logic only if it's load-bearing for detecting
   un-migrated base DBs; otherwise the schema_sha comparison covers it. Keep the flock and
   pg_advisory_lock unchanged. If a clone is corrupt, the escape hatch is dropping the clone DBs (or
   the periodic tmpfs wipe) — document that in a comment.

### R3-3. Parallelize remaining clone work

The rebuild loop is serial. Wrap the per-database work in a small thread pool (e.g.
`Concurrent::FixedThreadPool` or plain `Thread` batches of ~8): CREATE DATABASE TEMPLATE calls are
server-side and I/O-bound on tmpfs; parallelizing across 40 DBs cuts cold-rebuild wall time roughly
by the pool factor. Guard: PG serializes CREATE DATABASE from the same template — batch by distinct
source DB so parallel clones use different templates.

## Verification (after user's podman restart)

1. Rebuild DBs (restart wipes tmpfs): dev via `.devcontainer/setup-db.sh`, test via
   `RAILS_ENV=test bin/rails db:create db:migrate`. NEVER load the four WIP structure dumps.
2. Confirm workers: run a single-file test with no PARALLEL_WORKERS set and check it reports 16
   workers (or log `Concurrent.physical_processor_count`).
3. `time bin/rails test` twice (cold = clone build, warm = staleness check only):
   - warm-run wall target: (171s test phase + <15s overhead) ≈ ~3m05s or better, vs current ~3m28s
     (~35s overhead).
   - suite must stay 9115 runs, 0 failures.
4. Confirm unlogged tables active after rebuild: `relpersistence='u'` spot-check.
5. Confirm replica still streams after restart cycle (slot active=t, pg_is_in_recovery=t).

## Constraints carried over

- Never revert the four WIP `db/*_structure.sql` dumps.
- `podman compose restart` wipes tmpfs DB data → full rebuild required afterward.
- Any recreation wiping DB data beyond what the user's own restart causes needs explicit OK.
