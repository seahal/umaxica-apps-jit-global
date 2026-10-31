# Auth sign-in Email OTP lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the inspected code.
- `AuthEmailOtpChallenge` wraps issuance, verification and delivery in its OIDC-parent/Auth-session lock and then locks the contact owner and contact. `CredentialSecurityTransition#call` locks its actor before its OP flow/OIDC/ceremony work. A cycle requires both operations to reach the same actor and parent; that runtime overlap was not reproduced.
- `PARALLEL_WORKERS=1 bin/rails test test/models/auth_email_otp_challenge_test.rb` passed: 16 runs, 87 assertions, 0 failures, 0 errors, 0 skips. It does not prove lock order under independent contention.
- The isolated issuance reordering was not applied: verification and delivery would retain the opposite order. Contact re-read, dummy flows, competing mutations and connection failure must be addressed together. The full suite was not run.
