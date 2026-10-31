# APP TOTP removal Ticket write failure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added a nontransactional APP TOTP removal test that injects a connection error at the actual Ticket token update while the real removal and security transition execute. It observes the Ticket write, no Zenith TOTP update, the original active TOTP status, and the original Step-Up timestamp after rollback.
- The focused test passed: 1 run, 5 assertions. With `PARALLEL_WORKERS=1`, the commit-order, credential-removal, Passkey authorization/concurrency and lifecycle guard files passed together: 30 runs, 288 assertions, no failures or errors. RuboCop and `git diff --check` passed for the changed test.
- This injects an exception during a Ticket write, not an ambiguous database commit result or a real outage. Other credential types, outer Ticket transactions, the TOTP source audit and the remaining XDB-07 failure windows remain unverified.
