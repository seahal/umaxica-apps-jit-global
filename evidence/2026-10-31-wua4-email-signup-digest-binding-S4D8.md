# APP Email signup destination binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- The existing Email issuer file passed before the change (9 runs, 127 assertions). A synthetic existing transaction for the same owner, candidate and Flow with a different destination digest caused the prior issuer to insert a second transaction (1 focused failure).
- The issuer now locates existing transactions without filtering out a different digest, then refuses a mismatched digest or deadline with its existing binding-mismatch result. The focused case passed and established no new transaction, no code, no change to the existing transaction or Source cooldown (1 run, 6 assertions).
- The Email/Telephone issuer, delivery guard, concurrency and controller files passed together before a semantics-preserving helper extraction (173 runs, 1,796 assertions). After extraction, the full Email issuer file passed again (10 runs, 133 assertions). Scoped RuboCop and `git diff --check` passed.
- The mismatch was constructed directly; this does not establish a reachable production address mutation, all historical duplicate data, or complete XDB-14 coverage.
