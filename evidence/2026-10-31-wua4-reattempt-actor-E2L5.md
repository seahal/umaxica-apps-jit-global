# Secret reattempt actor availability

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A focused test showed a withdrawn Client could create a successor issuance (1 run, 1 assertion, 1 failure).
- After rechecking `login_allowed?` under the Client lock, `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_manual_reattempt_issuer_test.rb test/operations/client_secret_manual_issuance_invalidator_test.rb test/operations/client_secret_manual_reservation_concurrency_test.rb` passed: 19 runs, 271 assertions, 0 failures, 0 errors, 0 skips.
- Scoped `git diff --check` passed for the operation and test file. Independent-connection withdrawal races were not separately exercised.
