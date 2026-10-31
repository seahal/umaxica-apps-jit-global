# Passkey rename with an outer Ticket transaction

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the Passkey name writer and its existing tests; the results describe that worktree.

- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_mutation_concurrency_test.rb:14` passed: 1 run, 6 assertions. It exercises a standalone source-audit failure.
- A temporary nontransactional APP probe called `IdentityPasskeyNameCommitter` inside an outer `OpBaseAppRecord.transaction`, then rolled that transaction back. It passed 2 assertions: Zenith retained the renamed description and Ticket restored the previously consumed Step-Up timestamp. The probe removed only its own created records and was removed after execution.

This demonstrates an XDB-02 commit-boundary defect for an outer Ticket transaction. The ORG writer has analogous transaction structure but was not exercised by this probe. No production fix or HTTP exploit was verified.
