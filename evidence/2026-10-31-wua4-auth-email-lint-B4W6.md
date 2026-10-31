# Auth Email OTP scoped static checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the files checked here.
- Scoped RuboCop initially reported shadowed clock arguments and test formatting. The unused block arguments were renamed while preserving the fresh database clock reads; test formatting was corrected.
- `bundle exec rubocop app/models/concerns/auth_email_otp_challenge.rb test/concurrency/auth_email_otp_owner_lock_test.rb` passed: 2 files, no offenses.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` passed: 30 runs, 204 assertions, 0 failures, 0 errors, 0 skips.
- Real transport, a total deadline and the full suite remain unverified.
