# APP signup OTP issuer transaction lock

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- A nontransactional independent-connection test held an existing Email or Telephone OTP transaction row, started the public issuer, observed its PostgreSQL backend waiting on that exact row, then synthetically changed the transaction deadline before releasing it. Both issuers previously issued a code despite the newly mismatched deadline (2 runs, 2 failures).
- Existing OTP transactions are now locked before issuer binding checks. Both race cases passed afterward (2 runs, 6 assertions); the full issuer, guard, concurrency and controller group passed (175 runs, 1,802 assertions).
- Following a semantics-preserving Email helper extraction to satisfy the scoped linter, the race and Email issuer files passed again (12 runs, 139 assertions). Scoped RuboCop and `git diff --check` passed.
- The competing writer was synthetic and intentionally did not use the normal parent lock. This does not establish a production path that changes the deadline, cover every lock interleaving, or complete XDB-14. Test-created rows were removed by the test cleanup.
