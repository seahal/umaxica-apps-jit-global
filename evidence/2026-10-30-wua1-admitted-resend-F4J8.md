# WU-A1 admitted OTP resend after callback reorder

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current worktree changes were
  uncommitted during verification.
- A fixture-independent HTTP journey creates an OIDC handoff, attaches and confirms its binding,
  redeems admission and submits a fake-destination email resend. The allowed request succeeds and
  advances its OTP generation. After the sign-in sentry is stopped, a repeat request returns 503
  without changing that generation, the occurrence count or emitting an auth SID cookie.
- `bin/rails test test/integration/sign_entry_otp_admitted_order_test.rb test/integration/sign_entry_sentry_test.rb`:
  19 runs, 163 assertions, 0 failures, 0 errors, 0 skips. RuboCop on the new test passed.
- `bin/rails test test/security/invariants/csrf_verification_strategy_invariant_test.rb`: 5 runs,
  10 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/unit/security/standard_csrf_invariant_test.rb`: 1 error before assertions
  while loading all fixtures, caused by the `client_auth_admission_bindings.base_token_id` foreign
  key. The original full-fixture OTP controller suite remains blocked for the same reason. Real
  contact delivery and the complete WU-A1 boundary/concurrency matrix remain unverified here.
