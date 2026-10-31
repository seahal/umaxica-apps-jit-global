# Contact OTP issuance and verification device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- With a token instance read before a persisted device reassignment, APP Email issuance initially succeeded when the new test expected refusal (1 run, 1 assertion, 1 failure; the Telephone iteration was not reached). Both issuance operations now verify the locked device is still named by the locked token.
- Under the same synthetic reassignment, APP Email and Telephone verification initially accepted the code (2 runs, 6 assertions, 2 failures). Both verification operations now make that device-binding check before accepting proof.
- Issuance, delivery and verification files passed together: 74 runs, 1,024 assertions, no failures or errors. RuboCop passed for the four changed operations and two test files.
- Tests use transactional fixtures and synthetic reassignment. ORG cases, independent-connection races, real transport and the full XDB-14 commit-failure matrix remain unverified.
