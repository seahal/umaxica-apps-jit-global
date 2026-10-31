# APP Passkey removal audit failure after Ticket invalidation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added a nontransactional APP Passkey removal case that injects a connection error at the actual Zenith Passkey audit outbox insertion. A separate Ticket connection observes Step-Up invalidation committed at that boundary. The Zenith transaction rolls back the audit row, the Passkey remains active, and a repeat without new Step-Up is refused.
- The focused initial test passed: 1 run, 5 assertions. After adding the replay assertions, the commit-order, credential-removal and Passkey authorization/concurrency files passed together with `PARALLEL_WORKERS=1`: 29 runs, 291 assertions, no failures or errors. RuboCop and `git diff --check` passed for the changed test.
- This is an injected Zenith audit failure in standalone APP Passkey removal; it does not establish ORG behavior, an already-open outer Ticket transaction, real database outages, or every XDB-07 failure boundary.
