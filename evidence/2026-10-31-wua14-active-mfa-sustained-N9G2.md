# APP active MFA Passkey sustained limit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting this check.
- The existing active-MFA burst test passed first (1 run, 16 assertions). A separate test then performed Email OTP primary authentication and reached MFA before four bursts of five failed challenge requests, spaced 61 seconds apart in test time. All 20 requests returned to the MFA challenge; the 21st received 429 with `Retry-After: 900`, and the Flow remained MFA-pending.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/app_MFA_passkey_(burst|sustained)_limit_applies/'`: 2 runs, 64 assertions, 0 failures, 0 errors. RuboCop and scoped `git diff --check` passed.
- The Admission binding is confirmed directly, OTP delivery and time are test controlled, and limiter storage is in memory. Actual WebAuthn signatures, distributed timing, full browser admission and the full suite were not verified.
