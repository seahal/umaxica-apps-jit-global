# Passkey audit collision identity

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the code tested here.
- The focused APP test first showed that an existing matching UUID with an unexpected Chronicle actor was accepted (1 run, 1 assertion, 1 failure).
- After adding actor and subject checks, `PARALLEL_WORKERS=1 bin/rails test test/jobs/passkey_audit_delivery_job_test.rb test/jobs/contact_audit_delivery_job_test.rb test/jobs/social_audit_delivery_job_test.rb` passed: 18 runs, 144 assertions, 0 failures, 0 errors, 0 skips. The new case separately checks unexpected actor and subject and confirms the source remains unacknowledged.
- The new collision scenario uses APP; ORG-specific collision and independent-database outage testing were not performed. The full suite was not run.
