# P9 registry accept history monotonicity gate

- Date: 2026-10-10
- HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: dirty; existing changes were preserved. No application commit or remote write was made.
- Scope: require the database-derived transfer instant to advance both the legacy ownership period and the concrete ownership period before registry acceptance mutates history.

## TDD evidence

- Red: the new public-operation test produced a PostgreSQL strict-interval `CheckViolation` while closing the legacy period instead of the required domain-level `InvalidTransfer`.
- Green: after returning the locked legacy period from the owner check and validating both period boundaries, `test/operations/avatar_ownership_transfers_test.rb` passed with 14 runs, 85 assertions, 0 failures, 0 errors, and 0 skips.
- RuboCop passed for the changed operation and test; `git diff --check` passed.

## Full regression gates

- Rails full gate: `/tmp/run-p9-full.sh`, 42 explicit batches against the disposable isolated PostgreSQL fleet.
- Rails aggregate: 14,971 runs, 127,155 assertions, 3 failures, 0 errors, 0 skips.
- The three failures were confined to batch 038, `test/tooling/database_reconstruction_authority_test.rb`, because the known tracked `db/*structure.sql` files are empty and therefore cannot contain table definitions. No new failure occurred in any other batch.
- Vitest full gate: `/tmp/run-p9-vitest.sh`.
- Vitest result: 99 test files passed; 1,140 tests passed.

The structure-dump failures remain an existing repository recovery issue and are not counted as successful verification. The next implementation slice must begin only after this full gate record is available.
