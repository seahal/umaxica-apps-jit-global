# WU-4 passkey tests and suite loading

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes including these test edits and corporate authentication removal.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_passkey_name_committer_test.rb`: 4 runs, 22 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_registration_operation_test.rb`: 10 runs, 43 assertions, no failures, errors or skips. Cross-surface refusal was retained using the app and org models.
- `PARALLEL_WORKERS=1 bin/rails test test/policies/contact_registration_requirement_test.rb`: 2 runs, 44 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/policies/credential_relation_scope_test.rb`: 8 runs, 24 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/values/identity_step_up_ceremony_refusal_code_test.rb`: 24 runs, 32 assertions, no failures, errors or skips.
- `bin/rails test` loaded and started 17,032 tests using 16 processes. At record time it was still running; observed errors include references to deleted visitor constants in shared test setup and explicitly requested deleted visitor fixtures. No final suite counts are claimed.
- Test database preparation was used; no production persistence operation or external write was performed.
