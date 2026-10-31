# Passkey candidate revocation race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A non-transactional APP test ran the real attestation verifier, paused after verification, and committed device revocation on another connection before candidate recording resumed. The operation refused, the ceremony remained pending, the challenge stayed consumed, and no candidate existed. The test cleaned up its synthetic records.
- The race, APP/ORG Passkey registration, mutation and commit-order files passed together: 34 runs, 220 assertions, no failures or errors. This includes a new ORG superseded-token candidate refusal. RuboCop passed for both changed test files.
- Candidate-first ordering, an independent ORG race, failure at each database commit boundary, and full WU-A4/A5 acceptance remain unverified.
