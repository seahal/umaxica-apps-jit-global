# APP signup Email delivery and cancellation race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added a nontransactional test using separate PostgreSQL connections. It holds the real Email signup delivery guard at the transport boundary, starts signup cancellation, and checks `pg_blocking_pids` to establish that cancellation waits for the delivery connection. After the local fake transport returns, cancellation completes and the previously issued code is refused as `inactive_flow`.
- The focused race test passed: 1 run, 8 assertions. With `PARALLEL_WORKERS=1`, the race, signup delivery guard and committed-retry files passed together: 29 runs, 300 assertions, no failures or errors.
- RuboCop on the new test and `git diff --check` passed. The test uses a local fake transport, not SMTP; it covers delivery-first for APP Email only. Cancel-first concurrency, telephone, resend races, real transport deadlines and the remaining XDB-14 fault matrix are not established.
