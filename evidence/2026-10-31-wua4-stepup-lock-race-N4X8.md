# Step-Up Email parent lock concurrency

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the tested implementation.
- A nontransactional two-connection test holds the parent row, observes the delivery-result writer waiting on a PostgreSQL lock, obtains the Step-Up session with `FOR UPDATE NOWAIT`, commits cancellation and checks that the waiting delivery result is refused. Synthetic test records were removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/step_up_email_lock_order_test.rb test/operations/identity_step_up_email_code_issuer_test.rb test/operations/identity_step_up_email_delivery_recorder_test.rb test/operations/identity_step_up_ceremony_cancellation_committer_test.rb`: 20 runs, 115 assertions, 0 failures, 0 errors, 0 skips.
- This exercises the cancellation-first lock order at the delivery-result boundary. It does not establish every lock path, actual SMTP, the release-after-check race or full-suite status.
