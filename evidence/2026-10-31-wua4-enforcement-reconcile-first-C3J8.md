# Enforcement reconciliation-first Case end

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the tested code.
- A nontransactional test paused reconciliation after its Case update while its transaction remained open. A separate Case-end connection was observed blocked specifically by that reconciliation connection via `pg_blocking_pids`. After release, reconciliation and end completed, both audit events were present, and a later scan did not duplicate the reconciliation event. Synthetic records were removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/enforcement_reconciliation_end_race_test.rb test/jobs/enforcement_reconciliation_job_test.rb test/operations/enforcement_case_apply_failure_test.rb test/controllers/base/org/support/enforcement_approval_failures_test.rb` passed: 23 runs, 108 assertions, 0 failures, 0 errors, 0 skips.
- The test covers this ordering, not every effect writer, automatic principal-lock repair, reliable end-audit discovery or the full suite.
