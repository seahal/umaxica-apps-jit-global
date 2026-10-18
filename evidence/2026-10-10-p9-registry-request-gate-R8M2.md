# P9 registry request gate evidence

Date: 2026-10-10
Commit: `2a1644f73238839ed7ed513bd4681ea393a86682`
Worktree: dirty before and after the check; existing staged, unstaged, and untracked changes were preserved. No commit, push, reset, clean, stash, or worktree operation was performed.

## Scope

This gate covers the internal Avatar transfer registry request slice. The operation reserves a concrete transfer detail through the shared registry, enforces the existing pending-reservation and idempotency constraints, and is not wired to the public legacy transfer admission path. Public cutover remains gated by the later Grant, Group, and migration phases in `nine.md`.

## TDD and focused verification

- Red: removing `RegistryRequestOperation` produced `NameError: uninitialized constant AvatarOwnershipTransfers::RegistryRequestOperation` in `test/operations/avatar_ownership_transfers_test.rb` (10 runs, 51 assertions, 1 error).
- Green: the operation test passed with 10 runs, 58 assertions, 0 failures, 0 errors, and 0 skips.
- P9 focused regression set passed with 32 runs, 121 assertions, 0 failures, 0 errors, and 0 skips.
- RuboCop and `git diff --check` passed for the changed slice.

## Database preparation

The interrupted earlier full run left an isolated test fleet with schema/history mismatch. The approved disposable-fleet rebuild script was run with the existing manifest, host, role checks, and the complete 20-database migration scope. It verified ownership, recreated only the disposable databases and scoped roles, then completed `db:test:prepare` and `db:migrate`. No shared or production database was modified.

Because the repository's isolated-fleet safety contract requires one worker when `POSTGRESQL_ISOLATED_TEST_RUN_ID` is set, the full isolated gate used `PARALLEL_WORKERS=1`. This is a safety requirement for the disposable fleet, not a claim that the Rails suite lacks parallel-test support.

## Full Rails gate

Command: the existing `/tmp/run-p9-full.sh` 42-batch Rails suite, using the rebuilt disposable manifest and the repository's isolated-database safety variables.

Aggregate result: **14,967 runs, 127,114 assertions, 3 failures, 0 errors, 0 skips**.

All 42 batches completed. The three failures are the known `DatabaseReconstructionAuthorityTest` assertions that the 20 tracked `db/*structure.sql` files are empty. No other batch failed, and no new regression was identified in the registry request slice. This is not a full green gate because the schema-dump recovery issue remains open.

## Full Vitest gate

Command: `/tmp/run-p9-vitest.sh` (`bun run test`).

Result: **99 test files passed; 1,140 tests passed**.

## Boundary and remaining status

The registry request behavior is verified only as an internal operation. Registry accept/cancel behavior, public transport idempotency, four-direction integration, and public cutover remain unimplemented or gated by later phases. The known structure-dump failures must be resolved before a fully green Gate 0/Gate 4 claim can be made.
