# Sign-In Compensation

## Purpose

Document retry, rollback, and cleanup behavior for unfinished sign-in attempts. This boundary covers
email OTP, social login, and passkey / WebAuthn sign-in. Permanent-secret sign-in routes are retired.
This document does not cover sign-up completion or step-up freshness.

## Shared Completion Gate

- All successful sign-in routes must reach `establish_signed_in_session!`.
- Controllers may validate input and credential evidence, but they must not create `ClientToken`,
  `ClientDeviceSession`, or auth cookies directly.
- Session-limit handling is part of the completion gate, not a controller-local concern.

## Failure Behavior

- Blank or invalid credentials fail closed with inline form errors or deterministic error responses.
- Dummy or unknown-email OTP paths must remain timing-equalized.
- Social callback failures must not leave usable auth state behind.
- Passkey failures must not leave usable auth state behind.
- MFA-required completion returns a pending MFA state without minting a new login unit.
- Session-limit completion returns `:session_limit_pending` and the session-management path; it
  issues no token, cookie, or success audit.
- Hard reject returns a deterministic forbidden response and does not create a new session.

## Retry Behavior

- A failed credential attempt may be retried after the route-specific cooldown or rate limit allows
  it.
- A failed completion attempt must not double-count a login unit.
- A replayed or expired state / callback / challenge must fail closed and require a fresh flow.
- Expired ceremony transactions are cleaned by the dedicated recurring ceremony purge jobs listed in
  `config/recurring.yml`, not by `RetentionPurgeJob`. Cleanup removes only expired rows beyond the
  ceremony retention window, so active attempts are preserved and stale attempts retry through a new
  ceremony.

## Observability

- Log the failure reason and routing context.
- Do not log passwords, OTPs, tokens, cookies, or full request parameters.
- Keep timing-equalized dummy branches and rejected branches aligned where the route depends on
  existence checks.

## Related

- `docs/security/sign-in-sequence.md`
- `docs/security/session-limit.md`
- `docs/security/social-callback-boundary.md`
