# Auth Email OTP issuance-first release race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- A nontransactional test paused issuance after its Auth challenge update while locks remained held. A separate Contact-release connection was observed waiting on a database lock; after issuance and release completed, the issued code was refused. Synthetic records were removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` passed: 31 runs, 208 assertions, 0 failures, 0 errors, 0 skips. RuboCop corrected formatting in the race test before the final run.
- Actual delivery, a total transport deadline and the full suite were not checked.
