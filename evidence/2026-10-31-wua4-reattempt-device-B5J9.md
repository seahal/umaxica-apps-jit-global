# Secret reattempt device boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A test using the reloaded failed predecessor showed a revoked device could create a successor (1 run, 1 assertion, 1 failure). An earlier version of that test did not reload the predecessor and therefore passed for an unrelated denial; that result did not establish the device boundary.
- After validating the device and current token under the Client lock and rereading the predecessor under lock, `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_manual_reattempt_issuer_test.rb test/operations/client_secret_presentation_issuer_test.rb test/operations/client_secret_manual_issuance_invalidator_test.rb test/operations/client_secret_manual_reservation_concurrency_test.rb test/operations/client_secret_storage_confirmation_concurrency_test.rb` passed: 30 runs, 403 assertions, 0 failures, 0 errors, 0 skips. This includes revoked-device and superseded-token refusal.
- Scoped `git diff --check` passed for the operation and test file. Independent-connection race and failure windows remain unverified.
