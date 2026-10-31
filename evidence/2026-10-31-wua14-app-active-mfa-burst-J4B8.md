# APP active MFA Passkey burst limit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting this check.
- The existing MFA controller's failed-interruption case passed first (1 run, 14 assertions). The new test drives an APP Email OTP primary authentication into an MFA-pending flow, constructs its signed phase binding, and reaches the Passkey challenge page. An intermediate attempt without that phase binding received the expected phase refusal and was corrected.
- Five requests with a missing Passkey challenge returned to the MFA challenge; the sixth returned 429 with `Retry-After: 60`. `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/app_MFA_passkey_(challenge_answers_429|burst_limit_applies)/'`: 3 runs, 47 assertions, 0 failures, 0 errors.
- RuboCop corrected formatting in the edited test file. The test uses direct Admission binding confirmation, test OTP delivery, and in-memory limiter storage. It does not verify an actual WebAuthn signature, the sustained limit with pending MFA, distributed timing, or the full suite.
