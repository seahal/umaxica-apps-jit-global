# Enforcement and retention focused checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting this result.
- Ran `PARALLEL_WORKERS=1 bin/rails test` for `test/operations/enforcement_case_apply_failure_test.rb`, `test/jobs/retention_purge_legal_hold_test.rb`, `test/jobs/enforcement_expiry_job_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`, and `test/models/enforcement_case_apply_ordering_test.rb`: 16 runs, 55 assertions, no failures, errors or skips.
- These focused cases do not establish complete XDB-30 apply/end/retention/backfill ordering, every failure boundary, or all Enforcement recovery behavior.
