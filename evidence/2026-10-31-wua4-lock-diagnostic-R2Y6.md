# Enforcement lock convergence diagnostic

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the code exercised by this check.
- A focused assertion first failed because the logged error class did not distinguish an unestablished principal lock (1 run, 8 assertions, 1 failure).
- After introducing a specific error class, `PARALLEL_WORKERS=1 bin/rails test test/jobs/enforcement_reconciliation_job_test.rb test/operations/enforcement_case_apply_failure_test.rb` passed: 11 runs, 44 assertions, 0 failures, 0 errors, 0 skips.
- The existing log contains the Case public ID and error class. This does not retry the principal lock, repair missing downstream delivery, or establish concurrency safety. The full suite was not run.
