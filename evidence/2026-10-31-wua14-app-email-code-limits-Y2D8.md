# APP email sign-in code submission rate limits

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- The two submission cases initially errored in obsolete Admission setup (2 runs, 2 errors). The revised cases use the current entry and directly confirm the browser binding.
- The cases check the pre-limit redirects when there is no email challenge, followed by HTTP 429 and the respective 60- and 900-second retry hints.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/app_email_sign-in(_code_submission)?_answers_429/'`: 4 runs, 62 assertions, 0 failures, 0 errors.
- `bundle exec rubocop test/integration/auth_endpoint_burst_rate_limit_test.rb`: 1 file, no offenses.
- These tests do not submit an active OTP challenge. They use an in-memory limiter and direct binding confirmation; real browser behavior, distributed timing, and the full suite after this edit were not verified.
