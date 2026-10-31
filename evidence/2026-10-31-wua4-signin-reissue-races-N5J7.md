# APP Email sign-in reissue races

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the tested implementation.
- The owner-lock concurrency test starts a real-contact reissue on a separate connection, observes PostgreSQL reporting its blocked backend, then makes release, replacement by a dummy or another real contact, or cancellation win. In all four cases the reissue returns false and the winning OTP context remains unchanged.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/services/sign/in/otp_resend_service_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb test/services/sign_in_otp_resender_failures_test.rb`: 50 runs, 258 assertions, zero failures, errors or skips. `bundle exec rubocop test/concurrency/auth_email_otp_owner_lock_test.rb --format simple`: no offenses after correcting indentation.
- The concurrent cases exercise the issuer rather than a complete HTTP request; they do not establish behavior when the deadline passes during a blocked lock. The occurrence reservation order and cross-database commit failure behavior remain unresolved.
