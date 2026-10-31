# ORG Passkey count race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting this result.
- Two independent ORG source connections concurrently attempted registration for an Operator with nine existing keys. Exactly one new key and one registration audit were committed; the other operation returned the model's validation failure.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_registration_operation_concurrency_test.rb`: 4 runs, 15 assertions, 0 failures, 0 errors. RuboCop passed for the test file.
- This exercises the common registration operation and its owner lock. It does not prove a DB constraint against direct insertion, a slot backfill, or other writers and races.
