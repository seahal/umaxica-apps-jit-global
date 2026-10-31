# Limiter test entry setup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- Five recently revised APP limiter tests now issue an OIDC transaction and handoff through application APIs directly instead of calling the existing test entry helper. Binding confirmation remains direct.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/(app|org)_passkey_(options|verification)_answers_429|app_email_sign-in(_code_submission)?_answers_429/'`: 12 runs, 206 assertions, 0 failures, 0 errors.
- `bundle exec rubocop test/integration/auth_endpoint_burst_rate_limit_test.rb`: 1 file, no offenses.
- The combined group retains the previously documented limitations: direct binding confirmation, in-memory limiter storage, and no active OTP challenge for the code submission tests. The full suite was not rerun.
