# APP Email sign-in resend locked revalidation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had substantial uncommitted changes affecting the result.
- The resender passes its observed OTP generation to issuance. Under the existing contact and parent locks, issuance refuses a changed generation, cancellation, verification, changed binding or destination, and an expired OTP. Initial issuance remains callable without a prior generation.
- `PARALLEL_WORKERS=1 bin/rails test test/services/sign/in/otp_resend_service_test.rb test/concurrency/auth_email_otp_owner_lock_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb`: 44 runs, 235 assertions, no failures, errors or skips. Added sequential cases cover one microsecond before, at and after the OTP deadline, replacement, and real-contact cancellation. They do not establish a new concurrent barrier test.
- Scoped `bundle exec rubocop` passed for the concern, resender and service test. An initial run failed to load the test because `microsecond` was unavailable; the test was corrected to use rational seconds and rerun.
- Occurrence reservation still precedes issuance; cross-database commit ordering and refusal-side occurrence writes remain unresolved. Real delivery and a full suite were not tested.
