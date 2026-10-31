# Auth Email OTP delivery replacement races

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the tested code.
- Three nontransactional two-connection delivery cases hold the original Contact owner while the guard waits, then release the Contact, replace the generation with a fake-address challenge, or replace it with another real Contact. The stale guard refuses without calling the supplied transport block and leaves the current challenge unchanged. Synthetic records were removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` passed: 28 runs, 195 assertions, 0 failures, 0 errors, 0 skips.
- The tests use a local transport block and do not verify SMTP, its total deadline, or every ordering. The full suite was not run.
