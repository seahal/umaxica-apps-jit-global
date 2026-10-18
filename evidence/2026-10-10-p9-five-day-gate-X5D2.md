# P9 five-day reservation boundary gate

- Date: 2026-10-10
- Full HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: existing staged, unstaged, and untracked changes were preserved. No reset, clean, stash, commit, push, worktree, production, CI, or Podman operation was used.
- Database: disposable PostgreSQL fleet `20261010p8b`, manifest `tmp/acceptance-isolated-20261010p8b-ip.json`; test preparation was limited to that manifest and used `PARALLEL_WORKERS=1` as required by the isolated database safety contract.

## Slice

The transfer reservation registry now enforces the five-day validity boundary in PostgreSQL. A reservation exactly five days after `requested_at` is accepted; a value one second beyond five days is rejected by the database. The constraint is added unvalidated and validated by a following migration in accordance with StrongMigrations. Request/Accept/Cancel cutover remains a later P9 slice.

## TDD evidence

- Red: the boundary test failed because a five-day-plus-one-second row was accepted, 9 runs / 25 assertions / 1 failure.
- Green: `test/models/avatar_transfer_reservation_test.rb`, 9 runs / 27 assertions / 0 failures / 0 errors / 0 skips.
- Focused transfer registry set (`test/models/avatar_transfer_reservation_test.rb`, `test/operations/avatar_ownership_transfers_test.rb`, `test/operations/avatar_ownership_transfers_concurrency_test.rb`, `test/models/enforcement_triggers_test.rb`): 29 runs / 106 assertions / 0 failures / 0 errors / 0 skips.
- Supplementary newly added tests not present in the pre-existing 42-batch file manifest (`test/jobs/avatar_retention_purge_test.rb`, `test/models/avatar_concrete_ownership_period_test.rb`, `test/models/avatar_transfer_reservation_test.rb`, `test/services/avatar_access_grants_test.rb`, `test/unit/security/action_mailer_logging_policy_test.rb`): 24 runs / 83 assertions / 0 failures / 0 errors / 0 skips.
- Scoped RuboCop: 7 files inspected, no offenses.
- `git diff --check`: passed.

## Full regression gate

The 42 explicit Rails batches completed with 14,966 runs / 127,105 assertions / 3 failures / 0 errors / 0 skips. Every batch except batch 038 exited successfully. The three failures are the known `DatabaseReconstructionAuthorityTest` checks for the 20 tracked empty `db/*structure.sql` dumps; no new failure appeared in any other batch.

Because the pre-existing 42-batch file manifest predates the new untracked test files, those files were run separately as listed above. Their successful counts are not silently folded into the 42-batch total.

`bun run test` completed with 99 files and 1,140 tests passed.

No production data, external service, CI, or live deployment was accessed.
