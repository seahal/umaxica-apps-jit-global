# Auth Email OTP reference replacement race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the exercised code.
- A nontransactional two-connection case held the original Contact owner while verification waited and reissued the same ceremony for a fake address. The stale verifier refused with `binding_unavailable` and did not record verification. The companion case checks release first. Synthetic data was removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` passed: 24 runs, 170 assertions, 0 failures, 0 errors, 0 skips. RuboCop corrected indentation in the new test file before the final run.
- This is a real-to-fake replacement under verification, not real-to-real, delivery replacement or a real mail transport. The full suite was not run.
