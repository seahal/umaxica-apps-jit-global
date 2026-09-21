# Session Reset Policy

> **Partially superseded by Identity Authority inversion:** The reset-session vocabulary in this
> document remains useful only where it does not assign session, logout, token, or step-up freshness
> authority to `sign/id`. `acme/www` is the Session, Token, Account, Preference, Authorization, and
> downstream-token Authority. `sign/id` is ceremony-only. Existing sign-side physical tables/models
> do not imply sign-side authority. Do not use this document to reintroduce sign-side sessions,
> refresh, preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

This document is `app` / `com` / `org` This article describes the current behavior of Rails session
ID rotation (`reset_session`) as a countermeasure against session fixation attacks, which is common
to all three surfaces. The background to the design decision See
`adr/session-reset-on-privilege-transition.md`.

## Purpose

The authentication entity of this application is JWT It is a cookie and is not included in the Rails
session. The Rails session maintains the flow state before authentication (OIDC/social state/nonce,
email cooldown, WebAuthn challenge, etc.) only. `reset_session` regenerates the session ID at the
time of privilege transition and prevents the session ID planted by an attacker from being reused as
authenticated (defense in depth + temporary state cleaning).

## Reset points

`reset_session` is limited to the following three privilege transition points and aggregates each
point into a single choke point that must be passed.

| Transition Point | Single Choke Point                                              | Placement                                          |
| ---------------- | --------------------------------------------------------------- | -------------------------------------------------- |
| sign in          | `Authentication::Base#establish_signed_in_session!` → `#log_in` | Inside `log_in` (existing/no detour possible)      |
| step-up complete | `Sign::VerificationStepUpLifecycle#consume_step_up_session!`    | After DB commit/Before `flash[:notice]` assignment |
| logout           | `Authentication::Logoutable#logout_current_session!`            | Existing (sample shape)                            |

Sign-up completion goes through a dedicated sign-in method (`establish_signed_in_session!`), so it
is covered by the same chokepoint.

For stale sign-out submissions after another tab has already completed logout, the browser no longer
has the access/refresh cookie state required for an authenticated logout request. The sign-out
controller lets `authenticate!` reject the request and redirect to sign-in without calling the token
revoke primitive, resetting the Rails session again, or writing a logout audit event. See
`docs/security/logout-sequence.md`.

## Ordering constraints

The placement order of `reset_session` upon completion of step-up is a safety requirement.

- WebAuthn challenge is `consume_step_up_session!` before calling `verify_passkey!` Since it has
  already been consumed, it will not be destroyed by reset.
- Since `return_to` / `scope` was made into a local variable before the DB transaction, it is
  retained even after reset.
- The step-up session is consumed under its PostgreSQL row lock and destroyed before the completion
  transaction commits. It is not affected by Rails session resets, and a concurrent request cannot
  consume the same ticket twice.
- `flash` is stored in the Rails session, so `reset_session` is `flash[:notice]` It must be placed
  **before** the assignment (if it is later, the success notification will disappear).

## Non-goals

The following routes are outside the scope of this policy. Both go through `log_in`, so
`reset_session` has already been reached and is safe from fixed attacks.

- org Social Login (`sign/org/auth/omniauth_callbacks_controller`) `log_in` Direct call (excluded
  from regular entry aggregation to maintain MFA judgment behavior of existing staff).
- OIDC Direct call to `log_in` for RP login and passkey registration login.
- AAL promotion without going through `consume_step_up_session!` (risk enforcement, self-promotion
  when registering credentials).

## Credential and authenticator change invalidation

`reset_session` is not the session invalidation primitive for credential or authenticator changes.
It prevents Rails session fixation and clears browser flow state, but it does not revoke other
database-backed sessions and does not invalidate already-recorded step-up freshness.

Credential-equivalent changes use `CredentialSecurityTransition`:

- MFA level change, MFA disable, MFA reset, email verification, and secret credential removal call
  the shared transition service.
- The current browser session is retained by default so the user can complete the settings flow.
- Other active tokens for the same actor are revoked through `AuthenticationSessionRevoker`.
- Step-up freshness fields on all affected tokens are cleared through
  `IdentityStepUpCeremonyFreshnessRevoker`.
- Persisted step-up session rows for the affected tokens are expired.
- A durable Chronicle record is written with `ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION`
  or `OperatorChronicleEvent::CREDENTIAL_SECURITY_TRANSITION`.

The transition record must not contain raw cookies, OTPs, CSRF tokens, recovery codes, bearer
tokens, password values, or secret credential values. It records the reason, surface, request id
when available, and aggregate revoked session / step-up counts.

Password rotation is intentionally disabled for this release. The
`/identity/secrets/:secret_id/rotation` route returns `403 Forbidden` and does not update a secret,
does not call `CredentialSecurityTransition`, and does not write a password-change audit event. Full
password change remains a release blocker for any release that exposes password rotation UI.

MFA reset in the self-service settings flow means reset to `NOTHING`: the current session remains
usable, other active sessions are revoked, and existing step-up freshness is cleared. Operator
mediated account recovery remains a separate flow and must not be inferred from this self-service
reset route.

Step-up satisfaction remains server-side only. A prior step-up grant is usable only while the token
is still usable and the stored scope, AAL, method, purpose, audience, and session binding match the
current requirement. After a credential transition, the stored freshness is cleared, so an old grant
cannot authorize a later sensitive action.

Email verification in the Base app settings flow is a credential-equivalent transition. The
verification completion request retains the completing session, revokes other sessions for the same
actor, clears old step-up freshness, expires persisted step-up rows, and records a durable
credential transition audit entry.

## Remaining audit taxonomy risk

The durable event currently closed by implementation is `credential_security_transition.<reason>`
through Chronicle/IdentityAudit. The following taxonomy names still need a first-class durable
bridge before they can be treated as fully closed:

| Event                                           | Current status                                                                                    | Release risk                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `auth.step_up.required_missing`                 | Enforced by the step-up gate; durable taxonomy bridge not centralized.                            | Non-blocking if request denial evidence remains green.                |
| `auth.step_up.intent_mismatch`                  | Step-up intent rejects mismatched return targets; durable taxonomy bridge not centralized.        | Non-blocking.                                                         |
| `auth.csrf.rejected`                            | JSON requests now fail closed with `403`; durable taxonomy bridge not centralized.                | Non-blocking remaining risk for this release.                         |
| `auth.redirect.rejected`                        | `path_target.rejected` is emitted at authentication pt call sites.                                | Closed for pt rejection, broader taxonomy naming remains a follow-up. |
| `auth.authorization.denied`                     | Action Policy denial is enforced by controller pipeline; durable taxonomy bridge not centralized. | Non-blocking if IDOR request matrix remains green.                    |
| `security.sensitive_action.allowed`             | Not emitted as a durable taxonomy event.                                                          | Non-blocking; add only with a logging schema and retention owner.     |
| `security.sensitive_action.denied`              | Not emitted as a durable taxonomy event.                                                          | Non-blocking; add only with a logging schema and retention owner.     |
| `auth.sessions.revoked_after_credential_change` | Captured as aggregate counts on credential transition records.                                    | Closed as aggregate, not per-session event.                           |
| `auth.step_up.revoked_after_credential_change`  | Captured as aggregate counts on credential transition records.                                    | Closed as aggregate, not per-grant event.                             |

## Related

- `adr/session-reset-on-privilege-transition.md`
- `docs/security/step-up-mfa-status.md`
- `docs/security/sign-in-sequence.md`
