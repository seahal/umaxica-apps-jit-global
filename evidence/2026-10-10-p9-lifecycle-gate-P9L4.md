# P9 reservation lifecycle gate

- Date: 2026-10-10
- Full HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved; no reset, clean, stash, commit, push, or worktree operation was used.
- Scope: disposable PostgreSQL fleet `20261010p8b` from `tmp/acceptance-isolated-20261010p8b-ip.json`; Rails test preparation was restricted to the manifest databases. `PARALLEL_WORKERS=1` was retained because the isolated database safety contract requires it when `POSTGRESQL_ISOLATED_TEST_RUN_ID` is set.

## Implementation slice

The transfer reservation registry now records explicit `requested_at` and `expires_at` lifecycle timestamps. Normal reservation creation supplies both values using a five-day validity period. PostgreSQL owns the non-null/default/check guarantees; the check constraint is added unvalidated and validated by the following migration to satisfy the repository's StrongMigrations policy. The existing concrete-detail cardinality and idempotency constraints remain unchanged.

The model does not duplicate database presence validation for expression defaults. It still rejects an expiry that is not strictly after its request time when both values are present.

This is only a reservation lifecycle slice. Request/Accept/Cancel cutover, transfer-family authorization, cross-database recovery, and the remaining P9/P10/P12 acceptance conditions remain incomplete.

## Verification

Focused Red before the fix: the new lifecycle assertion failed because the columns were absent (`NoMethodError`), 8 runs / 21 assertions / 1 error.

Focused Green after the migration/model fix:

- `test/models/avatar_transfer_reservation_test.rb`: 8 runs, 23 assertions, 0 failures, 0 errors, 0 skips.
- `test/models/avatar_transfer_reservation_test.rb test/operations/avatar_ownership_transfers_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb test/models/enforcement_triggers_test.rb`: 28 runs, 102 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop: 5 files inspected, no offenses.
- `git diff --check`: passed.

Full Rails gate: 42 explicit batches, 14,966 runs, 127,109 assertions, 3 failures, 0 errors, 0 skips. All three failures are the pre-existing `DatabaseReconstructionAuthorityTest` checks for 20 tracked empty `db/*structure.sql` dumps; no new failure was observed in other batches.

Vitest: `bun run test` — 99 files passed, 1,140 tests passed.

A Vite test-mode build also completed successfully; its chunk-size messages were warnings only.

No CI, Podman, production database, external service, or live deployment verification was run.
