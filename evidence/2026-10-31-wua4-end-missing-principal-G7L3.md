# Enforcement Case end with missing release prerequisites

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- Before the change, three focused APP/ORG missing-principal and APP missing-operator cases returned instead of raising after the Case end committed (3 runs, 3 assertions, 3 failures).
- The release now requires the principal and applying operator to exist before attempting unlock. `PARALLEL_WORKERS=1 bin/rails test test/operations/enforcement_case_end_missing_principal_test.rb test/jobs/enforcement_expiry_job_test.rb test/jobs/enforcement_reconciliation_job_test.rb test/concurrency/enforcement_reconciliation_end_race_test.rb test/controllers/base/org/support/enforcement_approval_failures_test.rb` passed: 25 runs, 108 assertions, 0 failures, 0 errors, 0 skips. The new cases verify the end is committed and no `ended` event is written when the prerequisite is missing.
- The reused `audited_at` field can still exclude failed ends from the existing retry scan. Recovery, independent failure injection and the full suite remain unverified.
