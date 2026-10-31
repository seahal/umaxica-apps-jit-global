# ORG Passkey registration device recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- With `PARALLEL_WORKERS=1`, ran the existing revoked-device and superseded-token ORG registration cases in `test/operations/passkey_mutation_authorization_test.rb`: 2 runs, 12 assertions, no failures or errors. Both check that no Operator Passkey or Passkey audit outbox row is added and the ceremony transaction remains unconsumed.
- These cases do not exercise an independent-connection race or establish all XDB-01 requirements.
