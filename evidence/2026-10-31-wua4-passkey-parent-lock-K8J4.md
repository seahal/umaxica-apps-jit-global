# Passkey registration parent lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- Passkey registration finalization acquired the Step-Up session before its parent, opposite cancellation. The two registration committer files passed before the change: 19 runs, 104 assertions.
- After reordering, `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_passkey_registration_committers_test.rb test/operations/identity_passkey_registration_commit_order_test.rb test/operations/passkey_registration_operation_concurrency_test.rb test/concurrency/step_up_email_lock_order_test.rb` passed: 24 runs, 123 assertions, 0 failures, 0 errors, 0 skips.
- The independent Email race in this run is not a Passkey cancellation race. Full reauthentication and the full suite were not verified here.
