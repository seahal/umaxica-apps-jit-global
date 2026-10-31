# APP MFA Passkey sustained limit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting this check.
- The APP MFA burst and sustained tests initially produced 2 runs, 8 assertions and one error in the sustained case's obsolete Admission setup. The sustained case now creates the current OIDC handoff, directly confirms its binding, and checks all 20 pre-limit redirects and the 429/900-second retry hint.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/app_MFA_passkey_challenge_answers_429/'`: 2 runs, 31 assertions, 0 failures, 0 errors. RuboCop passed after removing an extra blank line.
- The tests do not establish behavior for an active MFA challenge, a full Base browser journey, distributed limiter storage, or the full suite.
