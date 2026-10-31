# APP Passkey verification rate limits

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- The two APP verification cases initially errored during obsolete Admission setup (2 runs, 2 errors). Their setup was updated to the current Admission sequence, with the binding confirmed directly.
- The tests now check that missing challenges receive HTTP 400 before the burst and sustained limits produce HTTP 429. The sustained case also checks `Retry-After: 900`.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb -n '/app_passkey_verification_answers_429|org_passkey_(verification|options)_answers_429/'`: 6 runs, 108 assertions, 0 failures, 0 errors.
- `bundle exec rubocop test/integration/auth_endpoint_burst_rate_limit_test.rb`: 1 file, no offenses.
- `git diff --check` reported pre-existing trailing whitespace in `Gemfile:209`; that unrelated file was not changed for this check.
- The limiter used in-memory storage and the tests directly confirm the Admission binding. A complete browser journey, distributed timing, and the full suite after these test edits were not verified.
