# App TOTP Credential Lifecycle and Attempt Binding

Status: Accepted (2026-09-20)

## Context

TOTP is an app-only authenticator in UMAXICA. The credential status reference and the
credential row are the authority for whether a TOTP may be used. A previous retry
implementation treated all active TOTP credentials on one client as one verification
pool, reset failures after a time window, and temporarily locked the account. That
allowed a failed guess against one authenticator to affect every authenticator and
allowed a correct code to revive a temporary lock.

## Decision

`ClientTotpCredentialStatus` and
`client_totp_credentials.user_identity_totp_credential_status_id` remain the single
credential lifecycle authority:

* `ACTIVE` is usable and consumes one registration slot.
* `INACTIVE` is not usable but retains a registration slot.
* `REVOKED` is terminal and permanently unusable.
* `DELETED` is a deletion state and does not consume a slot.
* `NOTHING` is not a usable credential and does not consume a slot.

Each credential stores a consecutive failed-verification count from 0 through 100.
Successful verification resets that credential's count to zero. A failed verification
increments only the credential to which the attempt was bound. The 100th failure and
the `REVOKED` transition are one row-locked PostgreSQL state transition. Time passage,
resend, another browser session, and a correct code received after revocation do not
reset or revive the credential.

An attempt is bound to exactly one actor-owned credential. One active credential may be
selected automatically. When two active credentials exist, the client selects the
credential with its actor-scoped `public_id`; database-local IDs are not accepted from
the browser. The same contract is used by app sign-in MFA and app Step-Up. A selector
for another actor or a non-active credential is rejected without recording an attempt.

Registration is limited to two slot-consuming credentials (`ACTIVE` and `INACTIVE`).
The slot check and final insert are coordinated by locking the owning Client row and
then writing the credential. Both settings enrollment and the identity ceremony final
committer use this domain operation.

TOTP enrollment, sign-in, Step-Up, and settings remain app-only. No com or org TOTP
route, controller, or credential lifecycle is introduced. Org's actor-known Entra and
Passkey ceremonies remain separate.

## Consequences

The database check constraint rejects failure counts outside 0..100. The old TOTP-only
time-window and temporary-lock columns are no longer part of the lifecycle. PostgreSQL
row locking is required for the failure transition; a cache or process-local counter is
not authoritative. The rate limiter remains an auxiliary abuse control and does not
replace the credential state transition.

The settings list retains revoked rows and displays their status. It provides no
reactivation action. Account recovery, re-proofing, and AAL3 recovery are not created
by this decision; a future recovery flow must create and bind a new credential instead
of reviving a revoked secret.
