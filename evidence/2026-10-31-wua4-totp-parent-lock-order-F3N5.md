# TOTP enrollment parent lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the code tested here.
- Inspection found TOTP enrollment issuance, verification and finalization locking the Step-Up session before its parent. The cancellation path locks the parent before the session. The three enrollment files passed before the change: 19 runs, 243 assertions.
- After changing the order, `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_totp_enrollment_issuer_test.rb test/operations/identity_totp_enrollment_verification_committer_test.rb test/operations/identity_totp_enrollment_final_committer_test.rb test/operations/identity_totp_enrollment_device_concurrency_test.rb test/concurrency/step_up_email_lock_order_test.rb` passed: 21 runs, 253 assertions, 0 failures, 0 errors, 0 skips.
- The independent race in this run concerns Email delivery result, not TOTP enrollment against cancellation. The remaining inverse paths and full suite were not verified.
