# Enforcement Case end strict-loading failure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the tested implementation.
- An apply/end concurrency probe stopped while ending an access-blocking Case with `ActiveRecord::StrictLoadingViolationError`; it did not establish the intended race. A focused test of a freshly loaded Case independently reproduced the error.
- The other-blocking-Case query now selects the associated model from association metadata instead of lazily loading the effect. `PARALLEL_WORKERS=1 bin/rails test test/operations/enforcement_case_end_missing_principal_test.rb test/jobs/enforcement_expiry_job_test.rb test/jobs/enforcement_reconciliation_job_test.rb test/concurrency/enforcement_reconciliation_end_race_test.rb test/controllers/base/org/support/enforcement_approval_failures_test.rb` passed: 26 runs, 112 assertions, 0 failures, 0 errors, 0 skips.
- The failed probe used a stub for the external OP stop-delivery boundary, did not establish the apply/end outcome, and was removed. The full suite was not run.
