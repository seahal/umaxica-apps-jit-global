# APP Email signup OTP expiry binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- The Email OTP issuer suite passed before the change (8 runs, 119 assertions). A new operation test showed that an existing matching transaction with an expiry one second later than its parent issued a code (1 failure).
- The issuer now refuses an existing transaction whose expiry differs from the locked Flow. Synthetic earlier and later one-second mismatches both return the existing `binding_mismatch` result without changing the transaction or Source cooldown (1 run, 8 assertions).
- The Email issuer, signup delivery concurrency and Email signup controller files passed together (91 runs, 860 assertions). Scoped RuboCop and `git diff --check` passed.
- The test constructs inconsistent transaction data directly. It does not establish a reachable production writer that causes such a mismatch, verify every verification or delivery path, or close XDB-14.
