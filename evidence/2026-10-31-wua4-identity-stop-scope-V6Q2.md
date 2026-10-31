# Identity-stop scope validation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained substantial uncommitted changes affecting the implementation and tests.
- Focused tests showed that the recorder accepted an unsupported scope and that first-time APP and ORG OP application accepted it as an all-roots stop: 3 runs, 3 assertions, 3 failures before the change.
- The recorder now refuses any scope other than its existing `all_sessions` contract before changing the actor epoch. The OP invalidator refuses a mismatched realm or unsupported scope before creating a receipt or revoking roots. Tests cover APP and ORG unsupported scope, a mismatched APP realm, and missing/empty/other/zero/false recorder inputs.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb test/concurrency/op_authority_stop_concurrency_test.rb test/services/administrative_access_lock_test.rb test/services/oidc_access_token_authenticator_test.rb`: 58 runs, 307 assertions, no failures, errors or skips. After expanding sentinel coverage, the invalidator and sweep files passed: 31 runs, 150 assertions. Scoped RuboCop passed.
- The malformed events were synthetic. Existing historical event values, actual outage behavior, production data and the full suite were not inspected or tested.
