# P9 registry accept replay gate

- Date: 2026-10-10
- HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: dirty; existing changes were preserved and no application commit or remote write was made.
- Scope: an accepted registry transfer can be retried by the same authorized acceptance boundary and returns the recorded result without creating another ownership period or changing the recorded completion instant.

## TDD evidence

- Red: the new public-operation replay test reached the existing `InvalidTransfer: ownership transfer is already terminal` branch.
- Green: `test/operations/avatar_ownership_transfers_test.rb` passed with 15 runs, 91 assertions, 0 failures, 0 errors, and 0 skips after accepted reservations were made replayable as read-only recorded results. Expired and cancelled terminal states remain non-replayable.
- RuboCop passed for the changed operation and test; `git diff --check` passed.

## Full regression gates

- Rails full gate: `/tmp/run-p9-full.sh`, 42 explicit batches against the disposable isolated PostgreSQL fleet.
- Rails aggregate: 14,972 runs, 127,157 assertions, 3 failures, 0 errors, 0 skips.
- The three failures were confined to batch 038, `test/tooling/database_reconstruction_authority_test.rb`, because the known tracked `db/*structure.sql` files remain empty. No new failure occurred in any other batch.
- Vitest full gate: `/tmp/run-p9-vitest.sh`.
- Vitest result: 99 test files passed; 1,140 tests passed.

The structure-dump failures remain an existing repository recovery issue and are not claimed as successful verification. The replay behavior is implemented only in the internal registry operation; public transport cutover remains a later P12b concern.
