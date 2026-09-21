# OTP session/transaction binding verification

- Date: 2026-09-20
- Scope: `SignOtpCeremony` app/com sign-up email and telephone contract
- Working tree: existing unrelated local changes were preserved; no GitHub write was performed

## Finding and change

The service accepted a valid contact OTP without using the supplied `session_nonce`, even though
all four app/com sign-up controllers passed the sign-up ticket identifier as that value. A new
regression test first reproduced acceptance and consumption with a different nonce. The service
now requires the nonce to match the subject sign-up ticket `public_id` using a length check and
constant-time comparison. Missing or mismatched values return `:session_mismatch` before contact
lookup or OTP consumption.

## Verification

- RED: `PARALLEL_WORKERS=1 bin/rails test test/services/sign_otp_ceremony_test.rb` — 8 runs, 37 assertions, 1 failure; the mismatched nonce was accepted.
- GREEN focused: `PARALLEL_WORKERS=1 bin/rails test test/services/sign_otp_ceremony_test.rb test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb test/controllers/auth/app/sign/up/check/telephone/otps_controller_test.rb test/controllers/auth/com/sign/up/check/email/otps_controller_test.rb test/controllers/auth/com/sign/up/check/telephone/otps_controller_test.rb test/services/branch_coverage_batch6_otp_and_ops_test.rb` — 48 runs, 280 assertions, 0 failures, 0 errors, 0 skips.
- Static analysis: `bundle exec rubocop app/services/sign_otp_ceremony.rb test/services/sign_otp_ceremony_test.rb test/services/branch_coverage_batch6_otp_and_ops_test.rb` — 3 files inspected, no offenses.
- Full Rails suite: `bin/rails test` — 11,407 runs, 72,998 assertions, 0 failures, 0 errors, 5 skips.

The test commands used the repository test environment file and the live test PostgreSQL and
Valkey services. No real email or SMS delivery was used. This verifies the repository-side
transaction binding; it does not establish a distributed transaction across delivery providers.
