# Auth Email OTP owner lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- Before the change, `test/models/auth_email_otp_challenge_test.rb` passed: 16 runs, 87 assertions. Inspection found OIDC parent/session locks before the Contact owner and Contact locks in issuance, verification and delivery.
- All three now lock the owner and Contact first. Verification and delivery select a candidate from a writer-side snapshot and compare its reference with the locked current context before proceeding. The state diagram and transition inventory were updated.
- A nontransactional test holds the owner, observes verification waiting, acquires the parent with `FOR UPDATE NOWAIT`, releases the Contact and confirms verification refuses without recording proof. Its synthetic data was removed.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb test/models/auth_email_otp_challenge_test.rb test/integration/sign_entry_otp_admitted_order_test.rb` passed: 23 runs, 166 assertions, 0 failures, 0 errors, 0 skips. Scoped `git diff --check` passed.
- Only verification with release first was tested under independent contention. Issuance and delivery races, concurrent Contact-reference replacement, real transport and total timeout remain unverified; the full suite was not run.
