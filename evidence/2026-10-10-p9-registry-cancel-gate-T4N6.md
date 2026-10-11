# P9 registry cancel gate evidence

Date: 2026-10-10
Commit: `2a1644f73238839ed7ed513bd4681ea393a86682`
Worktree: dirty before and after the check; all existing staged, unstaged, and untracked changes were preserved. No commit, push, reset, clean, stash, or worktree operation was performed.

## Scope

This slice adds the internal `AvatarOwnershipTransfers::RegistryCancelOperation`. It authorizes cancellation against the concrete source organization, locks and reloads the registry, detail, Avatar, and current ownership, materializes expiry at the boundary, and changes no ownership period. It is not exposed through the legacy public transfer admission path.

## TDD and focused verification

- Red: before the operation existed, the new public-operation test failed with `NameError: uninitialized constant AvatarOwnershipTransfers::RegistryCancelOperation` (11 runs, 58 assertions, 1 error).
- Green: after implementation, the operation test passed with 11 runs, 64 assertions, 0 failures, 0 errors, and 0 skips.
- P9 focused regression set passed with 33 runs, 127 assertions, 0 failures, 0 errors, and 0 skips.
- RuboCop passed for the changed operation and test; `git diff --check` passed.

## Full Rails gate

Command: the existing `/tmp/run-p9-full.sh` 42-batch Rails suite against the disposable isolated PostgreSQL fleet.

Aggregate result: **14,968 runs, 127,124 assertions, 3 failures, 0 errors, 0 skips**. All 42 batches completed. The three failures are the known `DatabaseReconstructionAuthorityTest` failures caused by the tracked `db/*structure.sql` files being empty/incomplete. No other batch failed and no new regression was identified for registry cancellation.

The isolated fleet was used with its required `PARALLEL_WORKERS=1` safety setting because `POSTGRESQL_ISOLATED_TEST_RUN_ID` is active. This does not contradict the separately verified ability of the Rails suite to run with parallel workers outside that disposable-fleet safety contract.

## Full Vitest gate

Command: `/tmp/run-p9-vitest.sh` (`bun run test`).

Result: **99 test files passed; 1,140 tests passed**.

## Remaining status

Registry acceptance, public transport idempotency, four-direction transfer integration, ownership-period mutation during accepted registry transfers, and public cutover remain later P9/P10/P12 work. The known structure-dump failures keep the global gate from being fully green.
