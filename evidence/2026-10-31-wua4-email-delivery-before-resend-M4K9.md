# APP signup Email delivery before resend

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added an independent-connection test that holds the real Email delivery guard at a local fake transport, observes the resend issuer waiting on that delivery connection using `pg_blocking_pids`, then releases delivery. The issuer creates a new generation, the Flow keeps its original expiry and remains active, the old generation cannot be delivered again, and the replacement code verifies. The source cooldown was prearranged to have elapsed before the race.
- The focused test passed after the final assertion-style edit: 1 run, 15 assertions. Before that equivalent style edit, the race, signup delivery guard and committed-retry files passed with `PARALLEL_WORKERS=1`: 35 runs, 373 assertions, no failures or errors. RuboCop and `git diff --check` passed for the race test.
- The test uses a local fake transport and does not verify the numeric old-code comparison, telephone delivery-first resend, real SMTP behavior, a total transport deadline or all XDB-14 fault points.
