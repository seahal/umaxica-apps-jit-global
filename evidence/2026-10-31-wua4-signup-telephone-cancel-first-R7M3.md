# APP signup telephone cancellation before delivery

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added an independent-connection test that explicitly holds the signup Flow lock in the cancellation transaction, starts the telephone delivery guard and uses `pg_blocking_pids` to establish that delivery waits on that cancellation connection. The real termination service then cancels before the transaction commits; after commit the guard refuses without invoking the fake transport and the issued code is refused as `inactive_flow`.
- The focused test passed: 1 run, 10 assertions. With `PARALLEL_WORKERS=1`, the Email/telephone race, signup delivery guard and committed-retry files passed together: 32 runs, 328 assertions, no failures or errors.
- RuboCop and `git diff --check` passed for the race test. The outer transaction is an explicit test barrier; this does not establish production cancellation latency, real SMS behavior, resend races or all XDB-14 fault points.
