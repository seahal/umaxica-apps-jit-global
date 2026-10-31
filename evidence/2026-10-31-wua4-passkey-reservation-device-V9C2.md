# Passkey Secret reservation device boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A revoked-device test initially showed that Passkey-origin Secret reservation succeeded rather than raising (1 run, 1 assertion, 1 failure).
- After validating the device and current token under the Client lock, `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_passkey_reservation_issuer_test.rb test/operations/client_secret_manual_reservation_concurrency_test.rb test/operations/client_secret_storage_confirmation_concurrency_test.rb test/integration/app_secret_signup_journey_test.rb` passed: 39 runs, 1823 assertions, 0 failures, 0 errors, 0 skips. The tests include revoked-device and superseded-token refusal as well as the separate signup path.
- Scoped `git diff --check` passed for the operation and test file. Cross-database failure windows and independent-connection races were not established by this check.
