# Sign-in resend occurrence status lookup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted changes affected the tested code.
- The resender now looks up or creates each fixed occurrence status on the current database connection instead of retaining its ID in a process cache. A status creation rolled back with its transaction therefore cannot leave the removed cache entry behind.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/sign_in_otp_resend_serialization_test.rb test/concurrency/auth_email_otp_owner_lock_test.rb test/services/sign/in/otp_resend_service_test.rb test/services/sign_in_otp_resender_failures_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb`: 54 runs, 276 assertions, no failures, errors or skips. Scoped RuboCop passed.
- The test group did not inject a missing status followed by transaction rollback. Nested caller transactions, commit-result uncertainty, real delivery and the full suite were not verified.
