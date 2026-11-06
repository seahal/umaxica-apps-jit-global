# WU-A2 Auth OTP Commit-Failure Coverage

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree was uncommitted and contained 489 status entries before this evidence file was added.
The modified test was part of that worktree; no clean-checkout isolation was used. No application
code or schema changed in this slice.

Added a public-service regression test in
`test/concurrency/sign_in_otp_resend_serialization_test.rb` for an injected
`ActiveRecord::ConnectionNotEstablished` before the Auth transaction commits an OTP resend. It
verifies a `:service_unavailable` result, an unchanged existing OTP challenge, no `EmailOccurrence`
row, no increase in `OtpNotifierEmailDeliveryJob` queue entries, and no adapter delivery call.

Verification performed:

- `bin/rails test test/concurrency/sign_in_otp_resend_serialization_test.rb:181`: 1 run, 4
  assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/concurrency/sign_in_otp_resend_serialization_test.rb`: 9 runs, 39 assertions,
  0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/concurrency/sign_in_otp_resend_serialization_test.rb`: no offenses.
- `ruby -c test/concurrency/sign_in_otp_resend_serialization_test.rb`: syntax OK.
- `git diff --check`: passed.

The first targeted run errored because this test class does not include `assert_no_enqueued_jobs`.
The test was changed to compare the OTP notifier job count through the configured queue adapter;
both targeted and full-file runs then passed. This is a test-helper mismatch, not an application
failure.

This verifies the Auth commit-before-issuance failure row in two.md §10.8 for the App email sign-in
resend service. Other §10.8 workflows and the overall WU-A2 acceptance remain unverified here.

## Follow-up: initial App Email sign-in issuance

HEAD remained `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was uncommitted and had 491
status entries during this follow-up; no application code or schema changed.

Added `test/concurrency/auth_email_otp_owner_lock_test.rb` coverage that injects
`ActiveRecord::ConnectionNotEstablished` before the initial Auth OTP transaction commits through
`AuthEmailSignInOtpIssuer.call`. It verifies the exception remains explicit, the ceremony stays
admitted with no OTP challenge, the Contact cooldown timestamp is unchanged, and no OTP notifier job
is added.

Verification performed:

- `bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb:10`: 1 run, 6 assertions, 0
  failures, 0 errors, 0 skips.
- `bin/rails test test/concurrency/auth_email_otp_owner_lock_test.rb`: 15 runs, 71 assertions, 0
  failures, 0 errors, 0 skips.
- `bundle exec rubocop test/concurrency/sign_in_otp_resend_serialization_test.rb test/concurrency/auth_email_otp_owner_lock_test.rb`:
  no offenses.
- `ruby -c` for both changed tests and `git diff --check`: passed.

The first initial-issuance run used `assert_equal` with an expected nil challenge and failed with
the test framework's assertion-style diagnostic; it was changed to `assert_nil`, then the targeted
and file runs passed. The full-file run also printed the existing expected concurrent `Cooldown`
exception from its worker thread while reporting zero test failures.

Together with the resend test above, this verifies the pre-commit Auth failure boundary for initial
App Email sign-in issuance and explicit resend. It does not verify post-commit failures or WU-A2
completion.

## Follow-up: Email and Telephone signup issuance

HEAD remained `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was uncommitted and had 492
status entries during this follow-up; no application code or schema changed.

Added tests in `test/concurrency/signup_otp_issuer_binding_lock_test.rb` for the Email and Telephone
signup delivery issuers. Each injects `ActiveRecord::ConnectionNotEstablished` before the OP
transaction commits and verifies that the challenge transaction count and pending Flow state are
unchanged and that the relevant Email or SMS delivery queue count does not increase. The Email case
also verifies the candidate cooldown timestamp is unchanged.

Verification performed:

- `bin/rails test test/concurrency/signup_otp_issuer_binding_lock_test.rb:10`: 1 run, 6 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rails test test/concurrency/signup_otp_issuer_binding_lock_test.rb:61`: 1 run, 5 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rails test test/concurrency/signup_otp_issuer_binding_lock_test.rb`: 6 runs, 27 assertions, 0
  failures, 0 errors, 0 skips.
- RuboCop for the three changed test files: no offenses; all three `ruby -c` checks and
  `git diff --check` passed.

These sign-up checks cover only the pre-commit failure point. The other §10.8 failure/competition
points and WU-A2 acceptance remain unverified.
