# Passkey registration candidate device checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- Two APP candidate tests initially failed: revoked and superseded devices could record a verified candidate (2 runs, 2 assertions, 2 failures).
- Candidate creation now locks the already owner-locked actor's device and token in order and checks owner, usability, current token and ORG Standby context before recording the candidate. The previously consumed challenge remains consumed on refusal.
- The Passkey verification/finalization, mutation and commit-order files passed: 32 runs, 211 assertions, no failures or errors. Tests include APP revoked/superseded devices and ORG revoked-device/stale-Standby contexts. RuboCop passed on the changed operation and test files.
- Tests use transactional fixtures. Independent-connection races, ORG superseded-token candidate creation and all cross-database failure boundaries were not verified. Candidate rejection does not establish complete WU-A4 or WU-A5 acceptance.
