# Step 19 full Minitest after BCL removal

- Commit: `5d48f27bd8e8c0546965c7383e1f014aef62c189` on `feature`. The worktree was clean apart from
  the gitignored `three.md`.
- Actor: Claude Opus 5.5 (claude-opus-5-5).
- Command:
  `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`.
- Result: 15,235 runs, 128,932 assertions, 4 failures, 14 errors, 0 skips; exit 1; 992 s.
- Attribution:
  - 14 errors: the Avatar `committed tests require run-owned worker receipts` guard. These are known
    and BLOCKED because the user has not authorized the isolated fleet.
  - 3 failures: `DatabaseReconstructionAuthorityTest` (committed structure dumps). These are known
    and were already present in the 2026-10-14 runs.
  - 1 failure (new): `FqdnAvailabilityGateTest` "gate is the very first before_action". The Palm
    sign-entry `prepend_before_action :apply_sign_entry_cache_policy!` (commit `6e2c36b93`, carried
    over from Codex) put the cache policy ahead of the FQDN gate. Corrected by calling the existing
    `ensure_fqdn_gate_first!`. Afterwards the FQDN gate, Palm sign-entry and Palm controller tests
    gave 37 runs, 0 failures, 0 errors.
- No failure is attributed to the BCL removal.
- Not done: the full suite was not repeated after the one-line correction; only the targeted rerun
  above. Vitest was not rerun because no JavaScript changed.
