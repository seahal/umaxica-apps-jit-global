# ORG Passkey removal audit failure after Ticket invalidation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added a nontransactional ORG Passkey removal case that injects a connection error at the actual Zenith Passkey audit outbox insertion. A separate ORG Ticket connection observes Step-Up invalidation committed at that boundary. The Zenith transaction rolls back the audit row, the Passkey remains active, and a repeat without new Step-Up is refused; two other active Passkeys satisfy the ORG capacity guard.
- The focused case passed: 1 run, 7 assertions. With `PARALLEL_WORKERS=1`, the commit-order, credential-removal and Passkey authorization/concurrency files passed together: 30 runs, 298 assertions, no failures or errors. RuboCop and `git diff --check` passed for the changed test.
- This is an injected Zenith audit failure in standalone ORG Passkey removal; it does not establish an already-open outer Ticket transaction, real database outages, or every XDB-07 failure boundary.
