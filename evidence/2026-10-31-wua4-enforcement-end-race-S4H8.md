# Enforcement reconciliation versus Case end

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- A nontransactional test paused the active reconciliation scan after selecting a Case, ended it using the public end operation on another connection, then resumed the scan. Before the fix, the ended Case received a `sessions_revoked_at` timestamp (1 run, 3 assertions, 1 failure).
- The active reconciler now locks and rereads the Case, skipping it when no longer active or already ended. `PARALLEL_WORKERS=1 bin/rails test test/concurrency/enforcement_reconciliation_end_race_test.rb test/jobs/enforcement_reconciliation_job_test.rb test/operations/enforcement_case_apply_failure_test.rb test/controllers/base/org/support/enforcement_approval_failures_test.rb` passed: 22 runs, 100 assertions, 0 failures, 0 errors, 0 skips. A missing principal lock still leaves session revocation progress committed and reports the failure.
- The race covers end-first after selection. It does not prove every concurrent effect or repair missing principal-lock/end-audit delivery. The full suite was not run.
