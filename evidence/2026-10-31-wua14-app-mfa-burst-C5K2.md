# APP MFA Passkey challenge burst limit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- The focused case initially errored during obsolete Admission setup (1 run, 1 error). It now creates an OIDC handoff through application APIs and confirms the binding directly.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/app_MFA_passkey_challenge_answers_429_once/'`: 1 run, 8 assertions, 0 failures, 0 errors. Without a pending MFA flow, five requests redirect to sign-in; the next returns HTTP 429 with a 60-second retry hint.
- `bundle exec rubocop test/integration/auth_endpoint_burst_rate_limit_test.rb`: 1 file, no offenses after a whitespace correction.
- This does not verify a pending MFA challenge, sustained limits, a real browser, distributed limiter storage, or the full suite.
