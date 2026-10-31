# Auth Email OTP delivery-first cancellation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the tested code.
- A nontransactional test paused the delivery guard in its supplied transport block. A separate cancellation connection was observed blocked specifically by the delivery connection via `pg_blocking_pids`. After release, delivery and cancellation completed and verification of the old code was refused. The synthetic records were removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` passed: 29 runs, 200 assertions, 0 failures, 0 errors, 0 skips.
- The transport was a controlled local block. Actual SMTP, total transport timeout and database lock-timeout behavior were not established; the full suite was not run.
