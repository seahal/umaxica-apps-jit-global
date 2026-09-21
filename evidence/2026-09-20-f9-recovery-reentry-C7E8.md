# F9 recovery re-entry enumeration regression coverage

- Date: 2026-09-20
- Scope: app/com Enforcement Recovery and Withdrawal re-entry email starts
- Finding: existing flows already used dummy OTP state for ineligible or unknown addresses, but
  their independent-session public-response contract was not explicitly covered.

## Verification

- Enforcement Recovery characterization: `PARALLEL_WORKERS=1 bin/rails test
  test/integration/identity_recovery_entrypoint_render_test.rb` — 9 runs, 55 assertions,
  0 failures, 0 errors, 0 skips.
- Withdrawal re-entry characterization: `PARALLEL_WORKERS=1 bin/rails test
  test/integration/withdrawal_ceremony_reentry_test.rb` — 6 runs, 53 assertions, 0 failures,
  0 errors, 0 skips.
- Both tests compare eligible/registered and unknown addresses from independent sessions. They
  verify matching public response status, content type, cache contract, and OTP-step presentation;
  fake delivery observes one delivery for the eligible/registered address only.
- `bin/rubocop test/integration/identity_recovery_entrypoint_render_test.rb
  test/integration/withdrawal_ceremony_reentry_test.rb` — no offenses.
- The subsequent full suite after the sign-up OTP attempt-persistence test ran with
  `bin/rails test` — 11418 runs, 73057 assertions, 0 failures, 0 errors, 5 skips.

No production recovery logic was changed in this slice. No real email, SMS, provider, AWS, or
Cloudflare service was contacted. Provider timing and live delivery behavior remain unverified.
