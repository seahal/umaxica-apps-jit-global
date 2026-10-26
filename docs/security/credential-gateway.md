# Credential Gateway

> **Legacy Sign/Acme vocabulary:** The `sign/id` and `acme/www` names in this document are retained
> for historical placement and responsibility context. The current Rails implementation uses Auth
> as the ceremony service, Visa as the OIDC/Root Session authority, and Base as the browser RP. The
> current handoff is the opaque, generation-bound Auth/Visa contract documented in
> `docs/security/ceremony-grant-result.md` and `adr/visa-op-host.md`.

## Purpose

`sign/id` is the Credential Gateway and Credential Ceremony Zone for fixed URL, provider callback,
browser-origin, and credential-specific flows.

This document is the stable docs companion to `docs/identity/authority-boundary.md`.

In the current Rails route vocabulary, apply this boundary to Auth versus Visa/Base: Auth is the
credential gateway / ceremony host, Visa owns OIDC authority, and Base owns RP identity-management
settings.

## Allowed Sign/ID Responsibilities

`sign/id` may execute:

- passkey/WebAuthn registration and assertion ceremonies;
- OTP and TOTP ceremonies;
- social provider callback validation;
- sign-in and sign-up credential ceremonies;
- credential enrollment and credential assertion;
- step-up ceremony execution.

`sign/id` may own credential inventory and short-lived ceremony state needed for those ceremonies.
It may also write ceremony audit records.

## Prohibited Sign/ID Responsibilities

`sign/id` must not own:

- user sessions, refresh token families, token rotation, logout, session revoke, or session listing;
- preference writes, settings, dashboards, session-management UI, or account lifecycle;
- authorization decisions, downstream token issuance, or step-up freshness;
- account linking or account creation decisions beyond returning credential evidence to acme.

Existing sign-side tables, models, namespaces, or route names are compatibility placement only
unless a current ADR explicitly assigns credential inventory or ceremony state to `sign/id`.

Auth settings may keep only credential ceremony-backed settings:

| Surface | Allowed Auth settings scope   |
| ------- | ----------------------------- |
| `app`   | passkeys, TOTP, Google, Apple |
| `com`   | passkeys                      |
| `org`   | passkeys, Entra               |

Emails, telephones, birthdate, secrets, secret credentials, sessions, revocations, activities, and
withdrawal belong to Base identity. Retired Auth settings URLs must not redirect to Base identity;
they must be unroutable after migration.

## Current security-lock recovery scope

The APP/COM Base `/identity/recovery/session` entry is email OTP re-entry for an in-force,
visible `security_lock` whose release mode is `verification_required`. It requires an effective
email binding and the permitted verified email status. Unknown destinations and unbound
candidates take the existing dummy-response path and cannot receive a recovery ceremony.

Successful OTP verification issues a narrowly scoped recovery ceremony, not a Root Session or
RP session. The recovery completion consumes that ceremony to release the selected account's
eligible security lock. These routes do not implement a forgotten-password reset. The current
Auth route inventory has no general email-link password-reset flow; adding one requires its
own credential, expiry, one-time consumption and session-revocation contract rather than
reusing lock recovery or interpreting email submission as proof.

## Historical Sign/Acme Ceremony Contract

When acme delegates a ceremony, `sign/id` receives a ceremony grant and returns a signed ceremony
result. The result is not a session update, account update, preference update, token, or freshness
record.

`acme/www` consumes the result and commits all authority state.

## Related

- `docs/security/ceremony-grant-result.md`
- `docs/security/webauthn-rp-id-origin-boundary.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/step-up-ceremony-delegation.md`
