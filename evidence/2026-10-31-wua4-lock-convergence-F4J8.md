# Enforcement principal lock convergence

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code and test exercised here.
- A focused test first reproduced a missing principal lock being marked converged: 1 run, 4 assertions, 1 failure.
- After the change, `PARALLEL_WORKERS=1 bin/rails test test/jobs/enforcement_reconciliation_job_test.rb test/operations/enforcement_case_apply_failure_test.rb test/controllers/base/org/support/enforcement_approval_failures_test.rb` passed: 18 runs, 81 assertions, 0 failures, 0 errors, 0 skips.
- Session revocation is attempted before checking the lock. An unlocked principal leaves the Case pending with an error logged. The guard does not retry the lock, prove ownership of an existing lock, or recover missing OP/Chronicle delivery. Concurrency with ending a Case and recovery of already-failed Cases remain unverified. The full suite was not run.
