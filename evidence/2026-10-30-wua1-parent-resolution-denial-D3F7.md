# WU-A1 parent resolution failure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current worktree changes were
  uncommitted during verification.
- The sentry no longer converts parent lookup or intent errors into an absent flow. At the
  admission-binding HTTP boundary, the existing invalid-request handling rejects those errors
  before a ceremony session is attached or issued.
- `bin/rails test test/integration/sign_entry_sentry_parent_failure_test.rb test/integration/sign_entry_sentry_test.rb test/unit/security/sign_entry_classification_guard_test.rb`:
  25 runs, 197 assertions, 0 failures, 0 errors, 0 skips. App and org integration cases inject
  parent lookup failure and argument failure and check the binding, session count and SID cookie.
- RuboCop on the concern and new integration test passed.
- This does not prove all WU-A1 deadlines, concurrency or stopped-OTP behaviors. The parent lookup
  failure cases use a stubbed lookup boundary rather than simulating a live database outage.
