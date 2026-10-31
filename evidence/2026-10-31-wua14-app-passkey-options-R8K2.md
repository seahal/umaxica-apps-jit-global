# APP Passkey options sustained rate limit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- The two APP options cases initially ran with 13 assertions and one error in the sustained case's obsolete Admission setup. That case now uses the existing test entry and current Admission sequence, confirming the binding directly.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/(app|org)_passkey_(options|verification)_answers_429/'`: 8 runs, 144 assertions, 0 failures, 0 errors. The sustained APP options test checks 20 successful responses and a 429 with `Retry-After: 900`.
- `bundle exec rubocop test/integration/auth_endpoint_burst_rate_limit_test.rb`: 1 file, no offenses.
- The tests use in-memory limiter storage and direct binding confirmation. A full Base browser journey, distributed timing, and the full suite after this edit were not verified.
