# ORG Passkey audit delivery commit order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the test and implementation exercised here.
- A nontransactional ORG test injected an error at the Source acknowledgement update. A separate Chronicle connection observed the event before that error; Source stayed pending and the next scan acknowledged it without a duplicate Chronicle row. The synthetic records were cleaned up.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/passkey_audit_delivery_commit_order_test.rb test/jobs/passkey_audit_delivery_job_test.rb`: 8 runs, 79 assertions, 0 failures, 0 errors, 0 skips.
- This is an injected local failure, not a real outage or an ORG mismatched-identity case. Other delivery boundaries and the full suite remain unverified.
