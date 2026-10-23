# WU-04: visible Turnstile on the telephone sign-up OTP check (APP, COM)

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
  Unrelated uncommitted work of another session was present and not touched.
- Decisions: D-66, D-67 (authentication cycle `one.md`).

## Before (Red)

New request tests in `test/controllers/auth/{app,com}/sign/up/check/telephone/otps_controller_test.rb`
failed on both surfaces: the OTP page had no `turnstile` prop (`KeyError`), and a valid code with a
missing, invalid or unavailable Turnstile token advanced the flow (302 instead of 422).
Run: 21 runs, 2 failures, 2 errors.

## Change

- `Auth::{App,Com}::Sign::Up::Check::Telephone::OtpsController#update` calls `verify_otp_turnstile!`
  right after the session check and before the code is read (same order as the email OTP check).
- The telephone OTP page props carry `turnstile: turnstile_visible_props(challenge_id: SecureRandom.uuid)`.
- `docs/security/turnstile.md` lists the email and telephone OTP check rows for APP and COM.
- Baseline failures in the area fixed: `test/integration/telephone_signup_{http_delivery,source_proof_retry}_test.rb`
  (16 failures in G-1) posted without `confirm_using_mfa`, which telephone registration requires since
  the 2026-10-22 consent change; the tests now send it.

## After (Green)

- Telephone and email OTP controller tests (APP, COM), COM telephone checkpoint flow, APP/COM
  telephone registration tests: 139 runs, 0 failures, 0 errors.
- Telephone integration tests: 16 runs, 0 failures (were 16 failures in G-1).
- Refusal keeps the OTP attempt count and the ceremony transaction row unchanged, the flow at
  `CONTACT_PENDING` and no `otp_verified`; a retry with a valid token succeeds (A04-1 … A04-5).
- RuboCop on changed files: clean after autocorrect.
