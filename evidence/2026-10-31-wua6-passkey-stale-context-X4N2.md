# ORG Passkey registration context recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A focused bootstrap test read a Normal token, changed its stored context to Standby through a separate model instance, then passed the stale token to final registration. After correcting an initial test setup error for discoverable-credential metadata, it failed before the fix: 1 run, 1 assertion, 1 failure because registration succeeded.
- The final committer now rechecks Standby after acquiring and reloading the token lock, before creating a credential or audit.
- The Passkey mutation, verification/finalization and commit-order files passed: 28 runs, 195 assertions, no failures or errors. RuboCop passed for the changed committer and test.
- The test uses transactional fixtures and changes the token context directly; it does not prove that a normal production workflow mutates an existing token's context, nor does it prove a true independent-connection race. Auth-side candidate creation has a separate device/context recheck gap under investigation.
