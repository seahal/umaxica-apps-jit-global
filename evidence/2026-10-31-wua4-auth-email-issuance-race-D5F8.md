# Auth Email OTP release-first issuance race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the tested code.
- A nontransactional two-connection test held the Contact owner, observed OTP issuance waiting and acquired the OIDC parent with `FOR UPDATE NOWAIT`. After Contact release, issuance raised `AuthCeremonySession::InvalidTransition` and the original challenge context remained unchanged. Synthetic records were removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` passed: 30 runs, 204 assertions, 0 failures, 0 errors, 0 skips.
- Issuance-first versus release, real transport and the full suite remain unverified.
