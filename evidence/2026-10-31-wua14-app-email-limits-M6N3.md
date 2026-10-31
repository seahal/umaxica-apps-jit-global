# APP email sign-in IP rate limits

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- The two focused tests initially errored in obsolete Admission setup (2 runs, 2 errors). Their setup now uses current Admission and directly confirms the binding.
- The tests use distinct synthetic addresses to avoid confusing the per-address cooldown with the IP limits, check redirects for the admitted requests, and check 429 with retry hints of 60 or 900 seconds.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/app_email_sign-in_answers_429/'`: 2 runs, 31 assertions, 0 failures, 0 errors.
- `bundle exec rubocop test/integration/auth_endpoint_burst_rate_limit_test.rb`: 1 file, no offenses.
- Tests used in-memory limiter storage. Real email delivery, a full Base browser journey, distributed timing, and the full suite after this edit were not verified.
