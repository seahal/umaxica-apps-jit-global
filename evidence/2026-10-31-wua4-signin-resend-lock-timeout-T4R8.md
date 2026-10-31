# Sign-in resend lock timeout and deadlock response

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the result.
- The resender maps `ActiveRecord::LockWaitTimeout` and `ActiveRecord::Deadlocked` to its existing reported 503 dependency response. Other unexpected errors retain their existing behavior.
- A non-transactional test held the destination's PostgreSQL advisory lock on one connection, observed a second backend blocked, and waited for the configured lock timeout. The second request returned unavailable; the Auth context was unchanged and no occurrence was created. HTTP tests separately injected the two error classes and checked the existing 503 response and unchanged challenge.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/sign_in_otp_resend_serialization_test.rb test/concurrency/auth_email_otp_owner_lock_test.rb test/services/sign/in/otp_resend_service_test.rb test/services/sign_in_otp_resender_failures_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb`: 58 runs, 292 assertions, no failures, errors or skips. Scoped RuboCop passed after formatting fixes.
- No real database deadlock, lock failure after Auth commit, production DB behavior, real delivery, or full suite was tested. The caller-owned outer transaction defects remain unresolved.
