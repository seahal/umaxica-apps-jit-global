# pgmem test database backend: compatibility and performance

- Date: 2026-10-15
- Commit: `58d2d80c5c0040cd20a125c5d4734c818d7ef0f4`
- Worktree: uncommitted changes that the pgmem results depend on — `bin/test-pgmem`,
  `bin/pgmem-install`, `lib/tasks/test_pgmem.rake`,
  `lib/umaxica/test_environment/{database_backend,pgmem_server}.rb`, and edits to
  `config/application.rb`, `lib/umaxica/test_environment/database_safety.rb` and
  `test/support/parallel_test_database_cloner.rb`. The PostgreSQL results use the same worktree;
  the PostgreSQL path is unchanged by those edits.
- Host: the `global-devcontainer-core` container (Debian 13, x86_64, 32 logical CPUs, no cgroup
  memory limit; the host has 125 GiB RAM). Ruby 4.0.7, Rails 8.2.0.alpha (`rails-e02ee2057522`).

## Versions

- pgmem `v1.18.2`, `pgmem-1.18.2-linux-amd64.tar.gz`. The tarball sha256
  `4ca14608e65959ccbf83c62b34a9aeff879a02ee4a75d93edce9186edbdb5b56` matched the release
  `SHA256SUMS`. The executable's sha256 is
  `363f3d2ed927fa68331feae46f8746927e6f030a7a1e6ef45d6d6f3f6ae78fd8`.
- The pgmem server reports `PostgreSQL 18.3 (PGlite ) on wasm32-unknown-linux-gnu ... 32-bit`.
- The compose PostgreSQL is 18.6, and psql in the container is 18.6.

## Protocol and engine probes (scratch scripts run with the pinned binary)

- The subprocess protocol gave a `ready` message, then `snapshot` in 22 ms, `fork` in 9–10 ms each,
  `reset` in 9 ms, and a `shutdown` that exited 0. Every server listened on 127.0.0.1 on a port
  that the process chose.
- Two forks of one snapshot were isolated: a write in fork A was not visible in fork B. Reset
  restored fork A to the snapshot state. Each fork contained every database that the template had.
- `CREATE DATABASE ... TEMPLATE`, `COMMENT ON DATABASE`, advisory locks and `pg_stat_activity`
  all worked.
- Extensions: `citext`, `pgcrypto` and `btree_gist` (the only ones the schemas use) were created.
  `pg_cron` failed with `extension "pg_cron" is not available`.
- PL/pgSQL, deferrable foreign keys and `DEFERRABLE INITIALLY DEFERRED` constraint triggers
  worked. A deferred foreign key violation raised `PG::ForeignKeyViolation` at COMMIT, and a
  deferred trigger exception was raised at COMMIT. `NOT ENFORCED` foreign keys were accepted.
- `ALTER TABLE ... DISABLE TRIGGER ALL` while deferred trigger events were pending raised
  `PG::ObjectInUse: cannot ALTER TABLE "child" because it has pending trigger events`.
- Concurrency: with two connections, a read did not block while another transaction was open, an
  independent insert proceeded, and a conflicting insert waited and then raised
  `PG::UniqueViolation` after the other transaction committed.
- pgmem did not reject a wrong password. Trust-equivalent authentication on loopback was
  observed.

## Template build

`bin/test-pgmem` runs `test:pgmem:verify_endpoint db:create test:pgmem:create_replica_placeholders
db:test:prepare test:pgmem:clone_replicas`. All 20 base databases were migrated, with about 1,431
migration log lines, and all 18 replica databases were templated from their bases. The `template
db:test:prepare` step took 13.19–13.46 s, snapshot took 0.05–0.06 s, and five forks took 0.15 s.

## Test results

| Run | Backend | Workers | Runs | Failures | Errors | `Finished in` |
| --- | --- | --- | --- | --- | --- | --- |
| `test/models/avatar_assignment_test.rb` | pgmem | 1 | 17 | 0 | 0 | 1.52 s |
| `test/models/avatar_assignment_test.rb` | PostgreSQL | 1 | 17 | 0 | 0 | 1.87 s |
| `test/models` | pgmem | 4 | 3,901 | 0 | 14 | 34.30 s |
| `test/models` | PostgreSQL | 4 | 3,901 | 7 | 70 | 55.12 s |
| full suite | pgmem | default (not recorded) | 15,354 | 2 | 25 | 188.22 s |
| full suite | PostgreSQL | default (not recorded) | 15,354 | 40 | 705 | 282.06 s |

- The full-suite rows were run and reported by the user; the other rows were run in this session.
  The full-suite pgmem run reported `bin/rails test 196.57s`, `total 211.34s`, and a pgmem peak
  resident memory (VmHWM) of 31,904,140 kB. The `test/models` pgmem run peaked at 7,577,200 kB
  (template plus five forks). The 1-worker run peaked at 1,656,872 kB.
- `test/models` comparison: all 14 pgmem errors also failed on PostgreSQL. Seven of them are
  `PG::RestrictViolation` (SQLSTATE 23001) on `ON DELETE RESTRICT` foreign keys where the tests
  expect `ActiveRecord::InvalidForeignKey`. PostgreSQL 18.6 raises the same 23001
  (`test/models/visitor_token_test.rb` and `avatar_test.rb` reproduced it). Six are
  `committed tests require run-owned worker receipts`, which needs an isolated run. pgmem refuses
  isolated runs. One more is listed in the same set but was not classified separately.
- The extra PostgreSQL errors in `test/models` were mostly `PG::ForeignKeyViolation` on status
  and kind reference tables. For example, `client_sign_out_flow_kinds` is empty in both
  `test_app_ticket_db` and `test_app_ticket_db_0` on the compose PostgreSQL, although
  `db/app_tickets_migrate/20261006160000_seed_app_sign_flow_reference_data.rb` seeds it. pgmem
  migrates from an empty database on every run and has the rows. The compose test databases were
  not rebuilt.
- The full-suite failures were not classified on either backend. The user stated that the
  PostgreSQL errors come from a version difference and are out of scope. The pgmem failure log
  was not retained.

## Performance reading

- `test/models`: pgmem took 34.30 s and PostgreSQL took 55.12 s, a 1.61× difference.
- Full suite: pgmem took 188.22 s and PostgreSQL took 282.06 s, a 1.50× difference (94 s less).
  With pgmem's per-run setup included (`total 211.34s`), pgmem is still about 70 s faster than the
  PostgreSQL test phase alone. The wall-clock time of the PostgreSQL process, including boot and
  clone checks, was not measured.
- The comparison is not like-for-like. The PostgreSQL run stopped 745 tests early on
  failures/errors and recorded 6,883 fewer assertions, so its time is likely understated.
- The share of runtime spent in the database was not measured (for example with
  `EVENT_PROF=sql.active_record`).

## Not verified

- Rails-level firing of the deferred constraint triggers in the real schemas. Transactional tests
  never commit, so these triggers do not fire on either backend unless a test forces it.
- A log-level observation that `*_replica` connections reached the worker fork's port. The code
  retargets every configuration with `include_hidden: true` and verifies each endpoint's PGlite
  version and run nonce.
- Behaviour after a container rebuild. The binary lives in the bind-mounted, gitignored
  `tmp/pgmem/` and is installed with `bin/pgmem-install`, not by the image.
- The PostgreSQL 18.6 fixture failure `PG::ObjectInUse ... "avatars" ... pending trigger events`
  is not addressed by this work. pgmem is 18.3, so Rails' `supports_enforced_foreign_keys?`
  (`>= 18_00_04`) is false there, and fixtures take the `DISABLE TRIGGER ALL` path instead of the
  `NOT ENFORCED` path. A pass on pgmem says nothing about that failure on 18.6.

## SQL share of runtime (EventProf)

Both backends ran the same command shape: `PARALLEL_WORKERS=1 SAMPLE=2000
EVENT_PROF=sql.active_record`, `--seed 20261015`, using the same worktree as above.

| Backend | Runs | Failures | Errors | Total | `sql.active_record` | Share | Events | ms/event |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PostgreSQL 18.6 | 2,000 | 9 | 123 | 198.25 s | 103.24 s | 52.07% | 650,028 | 0.159 |
| pgmem 1.18.2 | 2,000 | 1 | 3 | 166.38 s | 57.98 s | 34.84% | 422,349 | 0.137 |

- Time outside SQL was 95.0 s on PostgreSQL and 108.4 s on pgmem. That is the floor for a
  single-worker run of this sample, whatever the database does. Removing every second of SQL time
  would therefore make this sample at most about 2.1× faster than PostgreSQL (198.25 / 95.0). The
  pgmem run was 1.19× faster.
- `sql.active_record` measures wall time inside the adapter, including Ruby-side result
  handling. The server's own share is therefore smaller than the figures above.
- Per-event time differed by about 14%. Most of the SQL-time difference came from the event
  count: PostgreSQL issued 54% more events. Its 132 failing tests mean the two runs did not take
  the same paths, and the cause of the extra events was not investigated.
- pgmem peaked at 3,887,128 kB (template plus two forks). The template step took 12.67 s, and the
  launcher reported `total 188.03s`.
