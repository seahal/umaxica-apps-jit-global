# TOTP enrollment first-write ordering

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the inspected implementation and tests.
- Inspected `IdentityTotpEnrollmentFinalCommitter`: under the actor and ticket locks it calls `ClientTotpCredential.create_for_user!` before consuming the registration Step-Up, candidate, child, parent transaction and continuity. The parent consumption stores the created credential's public reference. The outer principal transaction encloses the OP transaction, so the source mutation is attempted before the OP commit even though the source transaction normally commits later.
- With `PARALLEL_WORKERS=1`, the existing principal-write failure test passed: 1 run, 12 assertions. It injects failure at credential creation, observes the transaction and candidate remain unconsumed, and successfully retries. This test does not simulate an independent OP commit followed by a Zenith failure; its expectation describes the current source-first behavior, which conflicts with two.md XDB-10.
- `git diff --check` passed for the inspected implementation and test. No change to the writer, persistent data or authorization was made in this check. Same-Zenith audit and independent-connection commit-boundary failure coverage remain open.
