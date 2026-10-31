# Secret reservation device boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A revoked-device test initially showed that reservation succeeded rather than raising (1 run, 1 assertion, 1 failure).
- After validating device usability and current-token binding under the Client lock, `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_manual_reservation_issuer_test.rb test/operations/client_secret_manual_reservation_concurrency_test.rb test/operations/client_secret_manual_reattempt_issuer_test.rb test/operations/client_secret_presentation_issuer_test.rb test/operations/client_secret_manual_issuance_invalidator_test.rb` passed: 37 runs, 582 assertions, 0 failures, 0 errors, 0 skips. This includes revoked-device and superseded-token refusal.
- Scoped `git diff --check` passed for the operation and test file. Independent-connection race and cross-database failure windows remain unverified.
