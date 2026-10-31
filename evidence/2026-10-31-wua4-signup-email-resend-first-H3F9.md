# APP signup Email resend before old delivery

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added an independent-connection test using an explicit outer Flow transaction as a resend barrier. Once the resend connection holds that lock, `pg_blocking_pids` confirms that the old Email delivery waits on it. The real issuer creates a new generation after a prearranged elapsed cooldown; when the outer transaction commits the old guard refuses without invoking the fake transport. The Flow remains nonterminal with its original expiry, and the new code verifies.
- The focused test passed: 1 run, 15 assertions. With `PARALLEL_WORKERS=1`, the race, signup delivery guard and committed-retry files passed together: 33 runs, 343 assertions, no failures or errors. RuboCop and `git diff --check` passed for the race test.
- The outer transaction is a test barrier and the transport is local and fake. This does not verify the numeric old-code comparison, delivery-first resend race, telephone resend, real SMTP behavior, total transport deadline, or all XDB-14 fault points.
