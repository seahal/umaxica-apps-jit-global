# P9 expiry-before-create gate

Date: 2026-10-10

This evidence was collected against commit `2a1644f73238839ed7ed513bd4681ea393a86682` with the existing dirty working tree preserved. No production, CI, Podman, external-service, push, or commit operation was performed.

## Scope

When a new reservation is created for an Avatar, the creator locks and terminalizes an older pending reservation whose deadline has arrived before inserting the new pending reservation. The registry remains the authority; the public legacy transfer endpoints are not cut over by this slice.

## TDD evidence

- Red: after correcting the fixture setup, the new test failed with the database partial-unique violation `idx_avatar_transfer_reservations_one_pending_avatar` (11 runs, 32 assertions, 1 error).
- Green: the implementation passed the focused reservation test (11 runs, 35 assertions, 0 failures, 0 errors, 0 skips).

## Checks executed

- `bundle exec rubocop app/operations/avatar_ownership_transfers/reservation_creator.rb test/models/avatar_transfer_reservation_test.rb`: 2 files inspected, no offenses.
- `git diff --check`: passed.
- `/tmp/run-p9-focused.sh`: 31 runs, 114 assertions, 0 failures, 0 errors, 0 skips.
- `/tmp/run-p9-full.sh`: all 42 Rails batches completed; 14,966 runs, 127,119 assertions, 3 failures, 0 errors, 0 skips. The only failing batch was 038, with the same three pre-existing `DatabaseReconstructionAuthorityTest` failures for the twenty empty tracked `db/*structure.sql` files. No other batch failed.
- `/tmp/run-p9-vitest.sh`: 99 test files and 1,140 tests passed.

The Rails run used the repository's isolated-database safety configuration, including `PARALLEL_WORKERS=1` for the disposable manifest. Parallel execution support remains intact; this setting prevents workers from sharing the same isolated catalog.

## Remaining scope

The registry is still not the public Request/Accept/Cancel authority. Four-direction admission, transport idempotency, generation/authority revalidation through the registry, and P10/P11/P12 work remain outstanding.
