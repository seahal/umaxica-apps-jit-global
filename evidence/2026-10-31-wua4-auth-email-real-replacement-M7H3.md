# Auth Email OTP real-to-real replacement race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the tested code.
- An independent-connection case held the original Contact owner while a verifier waited, issued a replacement generation for another verified Contact, then confirmed the old verifier refused and left the replacement context unchanged. The synthetic records were removed.
- The first expanded run had three test errors because a variable assigned only inside a Ruby block was not visible afterward; the test was corrected.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` then passed: 25 runs, 177 assertions, 0 failures, 0 errors, 0 skips.
- The race covers verification; delivery-side replacement, real transport and the full suite remain unverified.
