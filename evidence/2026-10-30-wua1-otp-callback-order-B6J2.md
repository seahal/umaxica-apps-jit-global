# WU-A1 OTP resend callback order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current changes were uncommitted.
- The app email OTP resend admission callback no longer prepends ahead of CSRF and the inherited
  sentry callback. A blocked unadmitted JSON request returns 503 without creating an email
  occurrence or ceremony session or issuing an auth SID cookie.
- `bin/rails test test/integration/sign_entry_sentry_test.rb test/unit/security/sign_entry_classification_guard_test.rb`:
  25 runs, 178 assertions, 0 failures, 0 errors, 0 skips. RuboCop on the modified controller and
  integration test passed.
- `bin/rails test test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb`: 1 run,
  48 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb`: 9 errors,
  0 assertions; all cases failed during full-fixture loading with a foreign-key violation on
  `client_auth_admission_bindings.base_token_id`. Admitted OTP resend behavior remains unverified
  in this session. The callback also now follows the other inherited callbacks, so its ordering
  against those callbacks needs a complete admission-flow verification.
