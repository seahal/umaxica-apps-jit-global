# Step-Up Ceremony Delegation

## Current admitted path

Base owns the existing Browser Session and the step-up requirement. A protected GET first returns
to Base's verification confirmation page. Its CSRF-protected POST issues a purpose-specific opaque
admission bound to the actor, surface, session, scope and destination. Auth GET displays a
nonconsuming continuation; Auth POST accepts that admission, rotates ceremony-local continuity,
and redirects to a clean URL. Auth root credentials are unnecessary for this path.

Auth verifies an allowed credential against the exact PostgreSQL transaction. Its same-origin
handoff POST issues an opaque result in a cross-host form body. Base requires its original browser
transaction marker, current root session and configured Auth origin. Base rechecks the actual
credential and requirement on writers, then commits freshness, transaction consumption and Auth
continuity completion together on the actor-specific ticket connection. A result or redirect alone
does not authorize a protected operation. The original mutation POST is never resubmitted.

### First APP TOTP registration

Base may issue `bootstrap` only when credential state permits first registration. Confirmed Email
counts as configured; unavailable Passkey/TOTP history is not a bootstrap permission. Signed-in APP
Secret management has no bootstrap exception. Setup admission is connected on APP, COM and ORG;
Passkey registration and later credential-management integration remain unfinished.

APP TOTP enrollment uses an encrypted server-side candidate and a child registration transaction
bound to that Base permission. GET never starts or replaces enrollment. Repeated start preserves
the secret, deadline and failures. Auth verifies the first code without creating a credential;
Base consumes the opaque registration result and creates the credential. Registration evidence
has no achieved AAL, phishing-resistance or freshness claim. A separate ordinary assertion must
satisfy the original protected requirement. Cancellation closes the exact permission and returns
to a fixed Base dashboard.

Principal creation and ticket consumption span different databases. Their actor-lock protocol is
fail-closed, not distributed atomicity. A result retry may return the same existing active owned
credential; it cannot recreate or reactivate a missing or revoked credential. See the
[registration separation decision](../../adr/base-auth-ceremony-and-seven-rp-boundary.md#registration-evidence-separation-amendment-2026-10-04).

## Historical paths pending retirement

The Sign/Acme signed-grant description below documents remaining legacy callers. It is not the
contract for new admission or completion. Migration, credential changes, audit/notification
integration, retention and the broader regression campaign remain open.

## Boundary

Step-up has two separate parts:

- `sign/id` executes the credential ceremony.
- `acme/www` owns the session-bound freshness decision and storage.

`sign/id` must not store `recent_auth`, `sudo`, `last_step_up_at`, AAL freshness, or equivalent
session freshness. A successful sign ceremony is evidence only until acme consumes the signed
ceremony result.

Step-up is not sign-in and does not create a new `ClientToken`, `ClientDeviceSession`, or login
unit. It updates freshness on the existing session only after acme accepts the ceremony result. If
the session is revoked, the ceremony grant is replayed, or the identity does not match the current
session, the result consumer must fail closed.

## Flow

1. `acme/www` decides that a sensitive action requires step-up.
2. `acme/www` issues a ceremony grant for the required purpose and session.
3. `sign/id` executes the allowed credential ceremony.
4. `sign/id` returns a signed ceremony result.
5. `acme/www` validates and consumes the result.
6. `acme/www` commits or rejects step-up freshness for the session.

The `sign/id` completion boundary is one-time as well: the surface-local pending step-up row is
locked in PostgreSQL, the result is issued inside that transaction, and the row is destroyed before
commit. A concurrent request cannot issue a second result from the same ticket.

## Non-Goals

- Do not treat credential registration as step-up freshness: a credential that is just being
  registered does not silently satisfy a later sensitive action. The credential-management
  mutation itself is still behind the existing Step-Up boundary on every Base surface. The first
  credential may use the documented bootstrap path; subsequent create, update, and destroy
  requests require fresh, session-bound `settings_secret_credential` Step-Up. The direct secret
  credential routes and the dedicated removal routes share this requirement.
- Do not let policy code perform ceremony side effects.
- Do not use redirects or return targets as proof that step-up succeeded.

## Related

- `docs/security/authentication-assurance-levels.md`
- `docs/security/ceremony-grant-result.md`
