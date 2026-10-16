# pgmem as an In-Memory Test Database Backend

Rejected (2026-10-15). Owner decision.

## Context

The Minitest suite runs against the compose PostgreSQL 18.6. That server already keeps its data
on tmpfs, and the test environment creates UNLOGGED tables. The suite has 20 base and 18 replica
test databases, and `ParallelTestDatabaseCloner` gives each parallel worker its own
`CREATE DATABASE ... TEMPLATE` copies.

[pgmem](https://github.com/shibukawa/pgmem) `v1.18.2` is PGlite (PostgreSQL 18.3 compiled to
wasm32) served over the PostgreSQL wire protocol. Its subprocess control protocol can snapshot a
server and fork per-worker copies. We trialled it as an opt-in second backend
(`UMAXICA_TEST_DB_BACKEND=pgmem`) to see whether an in-memory server would make the suite
substantially faster. The trial kept PostgreSQL as the default, changed no production or
development database configuration, and refused to fall back from pgmem to PostgreSQL.

The measurements are recorded in `evidence/2026-10-15-pgmem-test-backend-P7M3.md`.

## Findings

- Compatibility was sufficient for this application. The trial built every test database from
  migrations inside the devcontainer in about 13 s. The `citext`, `pgcrypto` and `btree_gist`
  extensions, PL/pgSQL, deferred foreign keys and deferred constraint triggers all worked. Snapshot
  took about 50 ms and each fork about 10–30 ms, and forks were isolated from one another.
  `pg_cron` was unavailable.
- Speed improved, but not dramatically:
  - Full suite (15,354 runs, parallel): `Finished in` was 188.2 s on pgmem and 282.1 s on
    PostgreSQL, a 1.5× difference.
  - `test/models` with 4 workers: 34.3 s on pgmem and 55.1 s on PostgreSQL, 1.6×.
  - The PostgreSQL runs failed many more tests (745 against 27 on the full suite), so the two runs
    did not take the same paths.
- The ceiling is low. With EventProf on a fixed 2,000-test sample and one worker,
  `sql.active_record` was 52% of runtime on PostgreSQL and 35% on pgmem. Time outside SQL was
  95–108 s. Removing every second of SQL time would make that sample at most about 2.1× faster.
  pgmem made it 1.19× faster. Per-query time differed by only about 14%.
- Costs: peak pgmem memory reached about 31.9 GB on the full parallel run (about 1.8 GB per fork),
  and every run pays about 13 s to build the template.
- pgmem reports PostgreSQL 18.3. Rails enables `NOT ENFORCED` foreign key toggling only from 18.4,
  so on pgmem fixtures take a different referential-integrity path than on 18.6. A pass on pgmem
  is therefore not evidence about version-specific behaviour on the production major version.

## Decision

Do not adopt pgmem in the development environment or the test workflow. The compose PostgreSQL
remains the only test database backend. The trial launcher, backend selector, rake tasks and
cloner path are not kept in the repository.

## Consequences

- The suite keeps running on the same PostgreSQL version family as production, with no second
  backend to maintain and no per-run memory cost.
- Further speed work belongs outside the database server: the Ruby and Rails time outside SQL, and
  the number of queries issued. A server change cannot recover more than the measured SQL share.
- The trial found one issue that is independent of pgmem: the compose test databases lack
  reference rows that their migrations seed (for example `client_sign_out_flow_kinds`). It is
  recorded in the evidence above and is not resolved by this decision.

## Revisit when

- pgmem tracks a PostgreSQL release at or above the one production runs, and
- a measurement shows the SQL share of suite runtime large enough for a server change to matter.
