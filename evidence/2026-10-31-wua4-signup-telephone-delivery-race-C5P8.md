# APP signup telephone delivery and cancellation race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added a nontransactional APP telephone signup test using independent PostgreSQL connections. It holds the real telephone delivery guard at a local fake transport, observes cancellation blocked by that delivery connection using `pg_blocking_pids`, then releases delivery and verifies cancellation completes and the issued code is refused as `inactive_flow`.
- The focused telephone race passed: 1 run, 8 assertions. With `PARALLEL_WORKERS=1`, the Email/telephone race, delivery guard and committed-retry files passed together: 30 runs, 308 assertions, no failures or errors.
- RuboCop and `git diff --check` passed for the race test file. Cancel-first concurrency, resend races, real SMS behavior and transport deadlines, and the remaining XDB-14 failure points remain unverified.
