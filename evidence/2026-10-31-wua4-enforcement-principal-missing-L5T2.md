# Enforcement Case missing principal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- Two focused APP/ORG cases first found that applying a Case with a missing principal returned rather than raising (2 runs, 2 assertions, 2 failures).
- After requiring the principal lookup to succeed, `PARALLEL_WORKERS=1 bin/rails test test/operations/enforcement_case_apply_failure_test.rb test/jobs/enforcement_reconciliation_job_test.rb test/models/enforcement_case_apply_ordering_test.rb test/controllers/base/org/support/enforcement_approval_failures_test.rb` passed: 23 runs, 107 assertions, 0 failures, 0 errors, 0 skips. The job case confirms a logged failure and a pending, unaudited Case.
- This makes missing prerequisites observable; it does not recover missing principals or complete principal-lock and end-audit reconciliation. The full suite was not run.
