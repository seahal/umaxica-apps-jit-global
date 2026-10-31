# Enforcement apply failure state

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the changes tested here.
- The focused operation test first reproduced the mismatch: 2 runs, 7 assertions, 1 failure when a post-commit uniqueness error left the Case failed rather than active.
- After removing that state change, `PARALLEL_WORKERS=1 bin/rails test test/operations/enforcement_case_apply_failure_test.rb test/controllers/base/org/support/enforcement_approval_failures_test.rb test/jobs/enforcement_reconciliation_job_test.rb` passed: 17 runs, 74 assertions, 0 failures, 0 errors, 0 skips.
- The current reconciliation job does not retry a failed principal access lock. Already persisted failed Cases do not enter its active queue. These remain unresolved; no historical data was changed. The full suite was not run in this slice.
