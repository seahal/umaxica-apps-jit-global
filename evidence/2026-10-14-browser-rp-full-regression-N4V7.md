# Browser RP binding repair and full Rails regression

Date: 2026-10-14 UTC  
Commit: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`  
Branch: `feature`  
Worktree: extensively dirty before and after the checks (`1028` porcelain entries at record time); unrelated work was preserved.

The checks used the ordinary Rails test database manifest only. `POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset. No database reset, isolated database, manual cleanup, migration command, destructive rollback, or worker-receipt guard bypass was performed.

## Implementation and focused verification

The Browser RP coordinator now declares its public binding entry point and private helpers explicitly for the architecture debt checker. The Core BFF test helper initializes a missing refresh-token family before rotating the root token, which keeps the Device Session and Browser RP binding valid. The COM secret-credential regression keeps the existing setup redirect contract while supplying the CSRF token required by the current unsafe-request policy.

The focused contract selection was:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 \
  bin/rails test \
  test/controllers/base/app/identity_authority_slice_1a_test.rb \
  test/controllers/concerns/authenticated_response_cache_policy_test.rb \
  test/controllers/core/bff_surface_smoke_test.rb \
  test/integration/sign/com/credential_removal_constraints_test.rb \
  test/tooling/architecture_baseline_test.rb
```

It passed with **20 runs / 2,838 assertions / 0 failures / 0 errors / 0 skips**. The broader sign-out, RP authority, Tech completion, Browser RP, cache, Core, and credential selection passed with **141 runs / 3,608 assertions / 0 failures / 0 errors / 0 skips**. RuboCop reported no offenses for the five changed Ruby files; all five returned `Syntax OK`; and scoped `git diff --check` passed.

## Full Rails result

The full command was:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test
```

It completed in 1007.060284 seconds with **15,273 runs / 129,147 assertions / 3 failures / 15 errors / 0 skips**.

The three failures are the existing `DatabaseReconstructionAuthorityTest` checks for empty `db/*_structure.sql` dumps, including the conventional `db/structure.sql` and the publishing dump. The dumps contain only PostgreSQL session settings and the database-dump footer, so the schema-drift gate remains unresolved without an authorized schema reconstruction.

The fifteen errors are:

- one `RecoverySecretParallelGetTest` error where the parallel recovery request returned the existing `/sign` 302 despite the diagnostic showing a valid RP session, visitor, Device Session, current root and subject binding;
- fourteen Avatar committed-history/concurrency cases refused by `ParallelTestDatabaseCloner.verify_owned_worker_execution!` because this standard-database run has no run-owned worker receipts. They cover retention purge, ownership transfer, transfer reservation, concrete ownership periods, and moniker concurrency.

No failure or error in the full run came from the focused Browser RP, shared logout parent-child repair, OIDC authority, Tech completion, or CSRF contract selection. Those boundaries are locally implemented and current focused tests pass, while the broader acceptance gates remain open.
