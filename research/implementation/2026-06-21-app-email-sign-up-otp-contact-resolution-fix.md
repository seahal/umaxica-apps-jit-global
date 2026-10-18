# App Email Sign-Up OTP Contact Resolution Fix

## Status

Fixed. App email sign-up was broken at the OTP step; google/apple were unaffected.

## Symptom

On the app surface, email sign-up failed at the OTP verification step: a valid code was rejected
with the "session expired" message (`sign.app.registration.email.edit.session_expired`, HTTP 422).
Google and Apple sign-up worked because those flows never resolve a pending email contact.

## Root Cause

`Sign::App::Sign::Up::EmailsController#current_registration_email` resolved the pending
`ClientEmail` from the sign-up cycle via `sign_up_flow_locator.current` (no fallback). The step gate
(`SignUpStepGate#current_ticket`) resolves the _ticket_ via `current_sign_up_flow_ticket`, which
falls back to the sequence id (`session[:sign_app_up_sequence_id]`) when the locator session payload
is absent or its nonce no longer matches the cycle.

That asymmetry meant: when the locator payload drifted from the cycle nonce, the gate still found
the ticket (so `@sign_up_ticket` was set and the gate passed), but contact resolution returned
`nil`, so `valid_email_session?` failed and the flow was rejected as expired. Email is the only app
sign-up flow that derives its contact from `cycle.pending_contact_id`; telephone uses a session
public id and social does not resolve an email contact, so only email broke.

The regression came in as a one-line working-tree change that switched `current_sign_up_flow_ticket`
to `sign_up_flow_locator.current`, apparently to satisfy the `EmailsControllerCoverageTest::Harness`
unit test, which stubs `sign_up_flow_locator` but did not define `current_sign_up_flow_ticket`.

## Fix

- `current_registration_email` now uses `current_sign_up_flow_ticket` again, so contact resolution
  shares the gate's fallback-bearing ticket lookup.
- `EmailsControllerCoverageTest::Harness` defines `current_sign_up_flow_ticket` delegating to the
  stubbed locator, mirroring the real sequence-support concern.

## Test Notes

- Added a regression test in
  `test/controllers/sign/app/sign/up/check/email/otps_controller_test.rb`: "update accepts a valid
  otp when the locator nonce no longer matches the ticket". It drifts the cycle `nonce_digest` in
  the DB (a real-request-faithful way to make `locator.current` return nil while the sequence id
  still resolves) and asserts the OTP step still succeeds. It fails on the bad version (422) and
  passes on the fix.
- The pre-existing test "edit uses current registration email from session" appears to cover this
  fallback by calling `session.delete(...)` before the next request, but ActionDispatch integration
  tests rebuild the session from the cookie, so that mutation does not reach the next request -- the
  fallback path was effectively uncovered, which is why the regression slipped through green.

## Related

- `research/implementation/2026-06-21-social-sign-up-dual-writer-collapse.md` (email authority
  inversion still pending).
