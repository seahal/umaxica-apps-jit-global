# Passkey registration finalization device boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A focused app bootstrap test reproduced registration from a revoked device (1 run, 1 assertion, 1 failure).
- After checking the locked device and current token, the app registration, commit-order, app/org mutation authorization and registration-writer invariant tests passed: 26 runs, 177 assertions, 0 failures, 0 errors, 0 skips. This includes app revoked-device and superseded-token refusal, org revoked-device refusal, and existing org successful registration/retry.
- RuboCop passed for the three touched files; scoped `git diff --check` passed. Org superseded-token and independent-connection revocation races were not separately tested; this is not full XDB-01 acceptance.
- Subsequently, the org registration success, revoked-device and superseded-token cases passed together: 3 runs, 14 assertions, 0 failures, 0 errors, 0 skips. Independent-connection revocation races remain unverified.
