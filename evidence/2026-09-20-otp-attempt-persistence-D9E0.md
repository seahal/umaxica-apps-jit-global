# OTP failed-attempt persistence verification

- Date: 2026-09-20
- Scope: app/com sign-up OTP issue, verification, and reissue behavior

## Verification

- `PARALLEL_WORKERS=1 bin/rails test test/services/sign_otp_ceremony_test.rb
  test/services/sign_in_otp_resender_failures_test.rb test/services/sign/in/otp_resend_service_test.rb`
  — 22 runs, 107 assertions, 0 failures, 0 errors, 0 skips.
- The new sign-up boundary test records one invalid verification, reissues after the resend
  cooldown, confirms the failed-attempt count remains one, and confirms a later valid verification
  resets it to zero.
- Sign-in resend coverage continues to confirm `reset_attempts: false`; the focused run included
  the existing sign-in resend tests.
- `bin/rubocop test/services/sign_otp_ceremony_test.rb` and `git diff --check` passed.
- `bin/rails test` — 11418 runs, 73057 assertions, 0 failures, 0 errors, 5 skips.

No production OTP policy was changed in this slice. No real email, SMS, provider, AWS, or
Cloudflare service was contacted.
