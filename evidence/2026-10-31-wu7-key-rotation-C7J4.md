# WU-7 com preference key rotation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes affected the result.
- Before the added case, the selected unknown-key, expiry and issuer-record checks passed: 4 runs, 11 assertions. Added a codec test using an actual newly generated P-384 key and test-only registry records. It signs with the original active key, changes the active signing key while retaining the old key in grace, and verifies both tokens. It then verifies that revoking or retiring the old kid rejects the old token while the new token remains valid.
- The com JWT codec, shared legacy JWT claims, issuer record and registry tests passed: 57 runs, 370 assertions, zero failures, errors or skips. RuboCop passed on the modified test. The test exercises in-process keyset transitions; it does not deploy keys, verify their distribution between independent processes, or perform production rotation.
- Full-suite comparison and deployment key distribution remain unverified. No migration or non-test purge was performed.
