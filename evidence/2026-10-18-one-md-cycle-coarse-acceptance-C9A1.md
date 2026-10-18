# one.md cycle closure: coarse acceptance of implemented scope

- Date: 2026-10-18 UTC.
- Commit: `17903f7d121aa33efe29f2db9235c9aa5db4b001`. The worktree carries the uncommitted R1-R5
  implementation; every result below is for that worktree, not for the commit alone.
- Environment: `RAILS_ENV=test`, `UMAXICA_ENV_FILE=.env.devcontainer.example`, isolated fleet
  `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261017c1a2` (32 databases, PostgreSQL 18.6,
  `10.89.0.3/32:5432`) with its manifest-derived `POSTGRESQL_TEST_PREPARE_DATABASES`; seed 42061.
- Nature of this record: the user closed this cycle with a coarse acceptance of what is implemented.
  It is **not** a `two.md` Gate PASS: no Gate procedure was detailed or executed, and the `two.md`
  register stays `NOT_RUN`. Only checks that passed are recorded here, at the user's request.

## Full suites

| Suite    | Command                                  | Result                                                         |
| -------- | ---------------------------------------- | -------------------------------------------------------------- |
| Minitest | `bin/rails test --seed 42061`, 8 workers | 15,528 runs, 132,446 assertions, 0 failures, 0 errors, 0 skips |
| Vitest   | `bun run test`                           | 100 files, 1,157 tests passed                                  |

## Per-release test groups

Groups were selected by test file name and referenced class (scratch lists, not kept in the
repository); the hash is the SHA-256 prefix of each sorted file list.

| Group                                     | Files | List hash          | Workers | Result                                    |
| ----------------------------------------- | ----- | ------------------ | ------- | ----------------------------------------- |
| R1 context continuity                     | 12    | `0e62de7d27018118` | 8       | 134 runs, 822 assertions, 0 failures      |
| R2 session limit / ACTIVE-only            | 18    | `10d19921b4de6d77` | 8       | 187 runs, 1,650 assertions, 0 failures    |
| R3 connections / rename consumers         | 39    | `cb6bc8e14fe4cf3e` | 1       | 602 runs, 3,884 assertions, 0 failures    |
| R4 client IDs and callers                 | 299   | `11ceafbbd4cd9252` | 8       | 2,905 runs, 28,003 assertions, 0 failures |
| R5-WU02 epoch / outbox / identity events  | 24    | `c41a65421c9e792a` | 1       | 283 runs, 2,744 assertions, 0 failures    |
| R5-WU06 identity stop serialization       | 4     | `555242f1072cd7f9` | 1       | 116 runs, 521 assertions, 0 failures      |
| R5-WU08 Refresh delivery recovery         | 11    | `6949b974ab144a01` | 1       | 228 runs, 1,986 assertions, 0 failures    |
| R5-WU09/10 logout commit and BCL          | 6     | `a339bcbf31eef6a0` | 1       | 30 runs, 153 assertions, 0 failures       |
| R5-WU11-15 domain authority clients       | 8     | `735ba19d6fd87b47` | 1       | 54 runs, 436 assertions, 0 failures       |
| R5-WU16 browser completion / purge / DBSC | 21    | `5a7c650aa3d58737` | 1       | 120 runs, 428 assertions, 0 failures      |
| R5-WU17 cell wiring / admission           | 12    | `e7c9ac9d8d910e50` | 1       | 85 runs, 615 assertions, 0 failures       |

Earlier this cycle (same worktree, before the closure run): real Solid Queue worker
stop/kill/restart recovery and the contract-epoch cutover rehearsal
(`evidence/2026-10-18-r5-queue-restart-epoch-cutover-and-cross-process-G4X2.md`), and two-connection
ordering, cached reading caller and JWKS rotation outage
(`evidence/2026-10-18-r5-wu18a-two-connection-and-jwks-rotation-W18B.md`).

## Outside this acceptance

- R5-WU03A: stopped by user decision
  (`plans/backlog/2026-10-18-production-runtime-secret-isolation.md`).
- Gates of R5-WU04, WU05 and WU07: wait for WU03A isolation; WU05 capacity also needs Jump/Edge.
- R5-WU18A, WU19, WU18, WU20: frozen until WU03A is recovered.
- R4-WU02A / WU03 environment and cutoff, cross-process cases, WU08 time budget: not executed.
- US runtime: out of scope for this programme.
