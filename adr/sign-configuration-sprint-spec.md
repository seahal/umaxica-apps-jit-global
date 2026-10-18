# Sign Configuration Sprint Spec (2026-02-06)

> **Partial supersession (2026-06-02):** The vocabulary and security properties in this ADR remain
> useful, but authority ownership is superseded by `adr/identity-authority-boundary.md`. `acme/www`
> owns session, token, account, preference, authorization, downstream-token trust, and step-up
> freshness. `sign/id` owns only credential inventory and short-lived credential ceremony state.

This document fixes the remaining ambiguous points and is the source of truth for this sprint.

## Implementation Status

| Section                        | Status         | Notes                                                          |
| ------------------------------ | -------------- | -------------------------------------------------------------- |
| 1. SMS + Passkey Required      | ✅ Implemented | Passkey registration flow after SMS OTP is active              |
| 2. Unlink / Disable Conditions | ✅ Implemented | `AuthMethodGuard.last_method?` enforces no-lockout rule        |
| 3. Passcode                    | ✅ Implemented | `UserSecrets::IssueRecovery` service handles passcodes         |
| 4. Withdrawal (2-way)          | 🚧 Partial     | Reversible withdrawal implemented; permanent deletion deferred |
| 5. public_id Boundary          | ✅ Implemented | `UserPasskey` has `public_id` (string, 21 chars, unique)       |

---

## 1. SMS + Passkey Required (Login Establishment) ✅

### Adopted spec: A (no full login until passkey is completed)

- SMS OTP verification **does not** establish a full session by itself.
- After SMS OTP success, the user **must** complete passkey registration before a session is
  created.
- If a user already has an active passkey, SMS OTP success can complete login immediately.

### Implementation

- `Sign::App::Up::TelephonesController` redirects to
  `sign_app_up_telephone_passkey_registration_path`
- `PasskeyRegistrationController` (Stimulus) handles browser WebAuthn API
- Views at `sign/app/up/passkey_registrations/show.html.erb`

### OTP resend (SMS)

- Resend is allowed even if the telephone record is missing or unverified (no existence leak).
- Rate limit: 60s cooldown per session for resend attempts.
- Response is generic on success; rate-limited responses use a generic cooldown message.

## 2. Unlink / Disable Conditions (Social / Email / Telephone / Passcode) ✅

### Common guards (applies to all unlink/disable actions)

- **Recent StepUp required**: use the existing step-up gate (`Verification::Base::STEP_UP_TTL`,
  currently 15 minutes).
- **No lockout**: after removal, the user must still have **at least one** remaining authentication
  method.
- "Last method" removal is rejected with a user-facing error.
- Audit log entry is required for each unlink/disable action.
- Social-login unlink physically deletes the Google/Apple identity row after writing the audit log.

### Implementation

- `AuthMethodGuard.last_method?(actor, excluding:)` checks remaining auth methods
- Controllers use `require_step_up!(scope: "social_unlink")` for sensitive actions
- Flash message: `t("sign.app.settings.email.destroy.last_method")`

### What counts as an authentication method

- Email: `UserEmailStatus::VERIFIED` or `VERIFIED_WITH_SIGN_UP`.
- Telephone: `UserTelephoneStatus::VERIFIED` or `VERIFIED_WITH_SIGN_UP`.
- Passkey: `UserPasskeyStatus::ACTIVE`.
- Passcode: `UserSecretStatus::ACTIVE`.
- Social: Google/Apple identities in `ACTIVE` status.

### Telephone unlink interpretation

- Telephone is not mandatory.
- If removed, it is considered **SMS login disabled** for that user.

### Passcode disable rules

- `enabled=false` or destroy is treated as unlink and is guarded by the same rules.

## 3. Passcode (Issued After Passkey Registration) ✅

### Adopted spec

- After a passkey is registered, a passcode is issued automatically.
- Stored in DB as a `UserSecret` with `user_secret_kind_id = RECOVERY` and **hashed** (never
  plaintext).
- Plaintext is shown **only once** on a dedicated page, then removed from session.
- Re-issuing invalidates prior active passcodes (set to `REVOKED`).

### Implementation

- Service: `UserSecrets::IssueRecovery`
- Audit log event: `UserActivityEvent::RECOVERY_CODES_GENERATED` (id: 13)
- Audit log use event: `UserActivityEvent::RECOVERY_CODE_USED` (when used to authenticate)

## 4. Withdrawal (2-way only) 🚧

### Adopted spec (based on current implementation + tests)

- Two-way model is **"withdraw (reversible)" ↔ "recover"** within a fixed recovery window.
- Permanent deletion is **not** available via UI in this sprint.
- `/setting/withdrawal` should present **only the reversible path**.
- If permanent deletion is needed later, it must be moved to a separate flow (support or delayed
  job).

### Behavior

- Withdrawal scheduling starts the account lifecycle with `withdrawal_started_at`.
- Suspension/logical deletion sets `deactivated_at` and `discard_at`, and sets `purge_eligible_at` to the
  31-day recovery deadline.
- Recovery is available only after the one-hour recovery delay and before `purge_eligible_at`; it clears the
  withdrawal lifecycle timestamps and restores the retention sentinels.
- `withdrawn_at` is terminal history only. It must not drive recovery or withdrawal-gate decisions.
- Withdrawal gates are based on the current lifecycle and retention columns, not
  `PRE_WITHDRAWAL_CONDITION`.

### Status

- Reversible withdrawal: **Implemented**
- Permanent deletion: **Deferred** (not in this sprint)

## 5. public_id Boundary ✅

### Adopted spec

- In configuration area, `totps`, `passkeys`, and `secrets` must use `public_id` in routes and
  lookup.
- `UserPasskey` must be upgraded to include a `public_id` (string, 21 chars, unique).

### Implementation

- `UserPasskey` model includes `public_id` column (string, 21 chars, not null, unique index)
- Routes use `public_id` for passkey resources

---

Updated: 2026-04-04
