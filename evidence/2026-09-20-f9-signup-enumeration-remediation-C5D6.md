# F9 sign-up enumeration remediation

- Date: 2026-09-20
- Scope: app/com sign-up email and telephone entry points
- Finding: fresh sessions could distinguish an existing registered contact from a pending
  unregistered sign-up because the pending contact's overwrite cooldown returned HTTP 429 while
  the registered-contact dummy branch redirected to the OTP page.

## TDD and change

The new app/com email and telephone integration tests first reproduced the oracle from independent
sessions. The email RED result was 302 for the registered second request versus 429 for the pending
second request. The telephone RED result had the same 302 versus 429 split.

The pending overwrite-window branches now enter the existing dummy contact flow. They do not send a
new email/SMS, do not create or replace a pending record, and return the same OTP-page redirect as
the registered-contact branch. Existing locked-contact failure handling remains unchanged.

## Verification

- Email RED: 76 runs, 473 assertions, 2 failures; both failures were the expected registered versus
  pending response mismatch.
- Email GREEN: `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/up/emails_controller_test.rb test/controllers/auth/com/up/emails_controller_test.rb` — 76 runs, 471 assertions, 0 failures, 0 errors, 0 skips.
- Telephone RED: 54 runs, 302 assertions, 2 failures; both failures were the expected registered
  versus pending response mismatch.
- Telephone GREEN: `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/up/telephones_controller_test.rb test/controllers/auth/com/up/telephones_controller_test.rb` — 54 runs, 302 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop: the final targeted runs inspected all changed controller/test files with no offenses.
- Recovery characterization: `PARALLEL_WORKERS=1 bin/rails test
  test/integration/identity_recovery_entrypoint_render_test.rb` — 9 runs, 55 assertions,
  0 failures, 0 errors, 0 skips. Registered and unknown recovery starts were issued from
  independent sessions; their public response status, content type, cache contract, and OTP-step
  presentation matched, while the fake delivery adapter observed one delivery only.

## Remaining scope

This closes the reproduced F9 sign-up email/telephone response oracle for app and com. The
app/com Enforcement Recovery start response is now covered by an independent-session regression
test; withdrawal re-entry and other recovery-style OTP paths still require separate audit. No
real email, SMS, provider, AWS, or Cloudflare service was contacted.

## Post-change full-suite verification

- `bin/rails test` with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` —
  11418 runs, 73057 assertions, 0 failures, 0 errors, 5 skips. This includes the independent
  recovery/withdrawal regression tests and sign-up OTP attempt-persistence coverage added after
  the sign-up fix.
- The suite used the repository PostgreSQL and Valkey services. No external delivery or cloud
  service was contacted.
